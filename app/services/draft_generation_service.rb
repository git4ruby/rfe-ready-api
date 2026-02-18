class DraftGenerationService
  attr_reader :rfe_case

  def initialize(case_id)
    @rfe_case = RfeCase.find(case_id)
  end

  def call
    sections = rfe_case.rfe_sections.ordered
    return if sections.empty?

    sections.each_with_index do |section, index|
      generate_draft_for_section(section, index)
    end
  end

  def regenerate_for_section(section)
    draft = section.draft_responses.order(:version).last
    new_version = (draft&.version || 0) + 1

    content = call_openai(section)
    return unless content

    section.draft_responses.create!(
      tenant: rfe_case.tenant,
      case: rfe_case,
      position: section.position,
      title: "Response: #{section.title}",
      ai_generated_content: content,
      status: :draft,
      version: new_version
    )
  end

  private

  def generate_draft_for_section(section, position)
    # Skip if a draft already exists for this section
    return if section.draft_responses.exists?

    content = call_openai(section)
    return unless content

    section.draft_responses.create!(
      tenant: rfe_case.tenant,
      case: rfe_case,
      position: position,
      title: "Response: #{section.title}",
      ai_generated_content: content,
      status: :draft,
      version: 1
    )
  end

  def call_openai(section)
    client = OpenAI::Client.new

    # Retrieve relevant knowledge base context via RAG
    rag_context = retrieve_rag_context(section)

    response = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt(section, rag_context) }
        ],
        temperature: 0.3,
        max_tokens: 3000
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue Faraday::Error => e
    Rails.logger.error("OpenAI API error generating draft for section #{section.id}: #{e.message}")
    nil
  end

  def system_prompt
    <<~PROMPT
      You are an expert U.S. immigration attorney drafting a response to a USCIS Request for Evidence (RFE).

      Rules:
      - Write in formal legal language appropriate for USCIS submissions
      - Be factual, precise, and well-organized
      - Reference specific CFR sections and USCIS policy memos where applicable
      - Use headings and numbered points for clarity
      - Do not include speculative language or unsupported claims
      - Include placeholders in [BRACKETS] for case-specific details the attorney must fill in
      - Structure the response as a persuasive legal argument
      - Include a brief introduction, evidence summary, legal argument, and conclusion
      - When relevant knowledge base context is provided, incorporate those references, templates, and legal arguments into your response
    PROMPT
  end

  def user_prompt(section, rag_context = [])
    checklist_items = section.evidence_checklists.ordered.map do |item|
      "- #{item.document_name} (#{item.priority}): #{item.description}"
    end.join("\n")

    knowledge_context = if rag_context.present?
      formatted = rag_context.map.with_index do |ctx, i|
        source = ctx[:metadata]&.dig("title") || "Knowledge Doc"
        doc_type = ctx[:metadata]&.dig("doc_type") || "unknown"
        "--- Source #{i + 1}: #{source} (#{doc_type}) ---\n#{ctx[:content]}"
      end.join("\n\n")

      <<~CONTEXT

        RELEVANT KNOWLEDGE BASE CONTEXT:
        Use the following references from our knowledge base to strengthen the response with specific legal arguments, regulations, and templates:

        #{formatted}
      CONTEXT
    else
      ""
    end

    <<~PROMPT
      Draft a response for the following RFE issue:

      ISSUE TYPE: #{section.section_type.humanize}
      ISSUE TITLE: #{section.title}
      CFR REFERENCE: #{section.cfr_reference || 'N/A'}

      USCIS STATED:
      #{section.original_text}

      AI ANALYSIS SUMMARY:
      #{section.summary}

      EVIDENCE BEING SUBMITTED:
      #{checklist_items.presence || 'No specific evidence items listed yet.'}

      CASE CONTEXT:
      - Visa Type: #{rfe_case.visa_type}
      - Petitioner: #{rfe_case.petitioner_name}
      #{knowledge_context}
      Write a comprehensive draft response addressing this specific issue. Use [BRACKETS] for any case-specific details that need to be filled in by the attorney.
    PROMPT
  end

  def retrieve_rag_context(section)
    query = "#{section.title} #{section.original_text} #{section.summary}".strip
    return [] if query.blank?

    RagRetrievalService.new(
      query: query,
      tenant: rfe_case.tenant,
      visa_type: rfe_case.visa_type,
      limit: 5
    ).call
  rescue => e
    Rails.logger.warn("DraftGenerationService: RAG retrieval failed for section #{section.id}: #{e.message}")
    []
  end
end
