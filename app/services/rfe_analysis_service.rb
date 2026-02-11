class RfeAnalysisService
  VALID_SECTION_TYPES = RfeSection.section_types.keys.freeze
  VALID_PRIORITIES = EvidenceChecklist.priorities.keys.freeze

  attr_reader :rfe_case

  def initialize(case_id)
    @rfe_case = RfeCase.find(case_id)
  end

  def call
    update_progress("extracting")

    # Extract text from all RFE notice documents
    rfe_text = extract_all_text
    if rfe_text.blank?
      update_progress("failed", error: "No text could be extracted from uploaded documents")
      return
    end

    update_progress("analyzing")

    # Call OpenAI for analysis
    analysis = analyze_with_openai(rfe_text)
    return unless analysis

    update_progress("saving")

    # Create sections and checklists from AI response
    create_sections_and_checklists(analysis)

    # Transition case to review
    rfe_case.complete_analysis! if rfe_case.may_complete_analysis?
    update_progress("complete")
  rescue => e
    Rails.logger.error("RFE Analysis failed for case #{rfe_case.id}: #{e.message}")
    update_progress("failed", error: e.message)
    raise
  end

  private

  def extract_all_text
    documents = rfe_case.rfe_documents.rfe_notices
    texts = documents.filter_map do |doc|
      doc.update!(processing_status: :processing)
      TextExtractionService.new(doc).call
    rescue => e
      Rails.logger.warn("Failed to extract text from document #{doc.id}: #{e.message}")
      nil
    end
    texts.join("\n\n---\n\n")
  end

  def analyze_with_openai(text)
    client = OpenAI::Client.new

    response = client.chat(
      parameters: {
        model: "gpt-4o",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt(text) }
        ],
        temperature: 0.2,
        max_tokens: 4000
      }
    )

    content = response.dig("choices", 0, "message", "content")
    return nil if content.blank?

    parsed = JSON.parse(content)
    Rails.logger.info("OpenAI analysis returned #{parsed['sections']&.length || 0} sections")
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
    update_progress("failed", error: "AI returned invalid JSON")
    nil
  rescue Faraday::Error => e
    Rails.logger.error("OpenAI API error: #{e.message}")
    update_progress("failed", error: "AI service unavailable")
    nil
  end

  def create_sections_and_checklists(analysis)
    sections_data = analysis["sections"] || []

    ActiveRecord::Base.transaction do
      # Clear any existing sections from previous analysis
      rfe_case.rfe_sections.destroy_all
      rfe_case.evidence_checklists.destroy_all

      sections_data.each_with_index do |section_data, index|
        section = create_section(section_data, index)
        create_checklists(section, section_data["evidence_needed"] || [])
      end
    end
  end

  def create_section(data, position)
    section_type = data["section_type"]
    section_type = "general" unless VALID_SECTION_TYPES.include?(section_type)

    rfe_case.rfe_sections.create!(
      tenant: rfe_case.tenant,
      rfe_document: rfe_case.rfe_documents.rfe_notices.first,
      position: position,
      section_type: section_type,
      title: data["title"] || "Issue #{position + 1}",
      original_text: data["original_text"],
      summary: data["summary"],
      cfr_reference: data["cfr_reference"],
      confidence_score: (data["confidence_score"] || 0.5).to_f.clamp(0.0, 1.0),
      ai_analysis: {
        model: "gpt-4o",
        analyzed_at: Time.current,
        raw_section: data
      }
    )
  end

  def create_checklists(section, evidence_items)
    evidence_items.each_with_index do |item, index|
      priority = item["priority"]
      priority = "recommended" unless VALID_PRIORITIES.include?(priority)

      section.evidence_checklists.create!(
        tenant: rfe_case.tenant,
        case: rfe_case,
        position: index,
        priority: priority,
        document_name: item["document_name"] || "Evidence #{index + 1}",
        description: item["description"],
        guidance: item["guidance"],
        is_collected: false
      )
    end
  end

  def update_progress(stage, error: nil)
    progress = { analysis_progress: stage, analysis_updated_at: Time.current }
    progress[:analysis_error] = error if error
    rfe_case.update_column(:metadata, rfe_case.metadata.merge(progress))
  end

  def system_prompt
    <<~PROMPT
      You are an expert U.S. immigration attorney specializing in USCIS Request for Evidence (RFE) responses.

      Analyze the provided RFE notice and identify each distinct issue raised by USCIS. For each issue, provide structured data in JSON format.

      Rules:
      - Identify ALL distinct issues/requests in the RFE
      - Classify each issue into one of these section_types: "specialty_occupation", "beneficiary_qualifications", "employer_employee", "general"
      - Extract the exact text from the RFE that relates to each issue
      - Provide a clear summary of what USCIS is requesting
      - Include the relevant CFR reference if mentioned
      - Assign a confidence_score (0.0 to 1.0) for your classification accuracy
      - List specific evidence documents needed to respond to each issue
      - For each evidence item, assign priority: "required", "recommended", or "optional"
      - Do not include speculative language or legal advice
      - Focus on factual analysis of what the RFE is requesting

      Return a JSON object with this exact structure:
      {
        "sections": [
          {
            "title": "Short descriptive title",
            "section_type": "specialty_occupation|beneficiary_qualifications|employer_employee|general",
            "original_text": "Exact text from the RFE notice for this issue",
            "summary": "Clear summary of what USCIS is requesting",
            "cfr_reference": "Relevant CFR citation, e.g. 8 CFR 214.2(h)(4)(ii)",
            "confidence_score": 0.92,
            "evidence_needed": [
              {
                "document_name": "Name of the evidence document",
                "description": "What this document should contain",
                "guidance": "Tips for preparing this evidence",
                "priority": "required|recommended|optional"
              }
            ]
          }
        ]
      }
    PROMPT
  end

  def user_prompt(text)
    <<~PROMPT
      Analyze the following USCIS Request for Evidence (RFE) notice and identify all issues raised:

      ---
      #{text}
      ---

      Return the analysis as a JSON object with the structure specified in your instructions.
    PROMPT
  end
end
