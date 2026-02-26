class CaseSimilarityService
  MODEL = "text-embedding-3-small"
  DEFAULT_LIMIT = 5

  attr_reader :rfe_case, :tenant, :limit

  def initialize(rfe_case:, tenant:, limit: DEFAULT_LIMIT)
    @rfe_case = rfe_case
    @tenant = tenant
    @limit = limit
  end

  def call
    text = build_case_text
    return [] if text.blank?

    query_vector = generate_embedding(text)
    return [] unless query_vector

    # Find similar cases by looking at embeddings of other cases' documents
    # or by comparing against case-level embeddings
    scope = Embedding.where(tenant: tenant)
                     .where.not(embeddable: rfe_case.rfe_documents)

    # Search for nearest neighbors
    results = scope.nearest_neighbors(:embedding, query_vector, distance: :cosine)
                   .first(limit * 3) # fetch more to deduplicate by case

    # Group by case and pick the best match per case
    cases_seen = Set.new([rfe_case.id])
    similar_cases = []

    results.each do |embedding|
      next unless embedding.embeddable_type == "RfeDocument"

      doc = RfeDocument.find_by(id: embedding.embeddable_id)
      next unless doc

      case_id = doc.case_id
      next if cases_seen.include?(case_id)

      cases_seen << case_id
      found_case = RfeCase.find_by(id: case_id, tenant: tenant)
      next unless found_case

      similarity = (1.0 - embedding.neighbor_distance).round(4)
      similar_cases << {
        id: found_case.id,
        case_number: found_case.case_number,
        petitioner_name: found_case.petitioner_name,
        visa_type: found_case.visa_type,
        status: found_case.status,
        similarity_score: similarity,
        matched_content: embedding.content.truncate(200)
      }

      break if similar_cases.size >= limit
    end

    similar_cases
  rescue => e
    Rails.logger.error("CaseSimilarityService: #{e.message}")
    []
  end

  private

  def build_case_text
    parts = []
    parts << "Visa Type: #{rfe_case.visa_type}" if rfe_case.visa_type.present?
    parts << "Petitioner: #{rfe_case.petitioner_name}" if rfe_case.petitioner_name.present?
    parts << "Notes: #{rfe_case.notes}" if rfe_case.notes.present?

    # Include section content from RFE sections
    rfe_case.rfe_sections.each do |section|
      parts << section.content.truncate(500) if section.content.present?
    end

    # Include extracted text from documents
    rfe_case.rfe_documents.limit(3).each do |doc|
      parts << doc.extracted_text.truncate(500) if doc.respond_to?(:extracted_text) && doc.extracted_text.present?
    end

    parts.join("\n\n").truncate(4000)
  end

  def generate_embedding(text)
    client = OpenAI::Client.new
    response = client.embeddings(
      parameters: { model: MODEL, input: text.truncate(8000) }
    )
    response.dig("data", 0, "embedding")
  rescue Faraday::Error => e
    Rails.logger.error("CaseSimilarityService: OpenAI embedding API error: #{e.message}")
    nil
  end
end
