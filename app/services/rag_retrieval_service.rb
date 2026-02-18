class RagRetrievalService
  MODEL = "text-embedding-3-small"
  DEFAULT_LIMIT = 5

  attr_reader :query, :tenant, :visa_type, :rfe_category, :limit

  def initialize(query:, tenant:, visa_type: nil, rfe_category: nil, limit: DEFAULT_LIMIT)
    @query = query
    @tenant = tenant
    @visa_type = visa_type
    @rfe_category = rfe_category
    @limit = limit
  end

  def call
    return [] if query.blank?

    query_vector = generate_embedding(query)
    return [] unless query_vector

    scope = Embedding.where(tenant: tenant, embeddable_type: "KnowledgeDoc")

    # Filter by metadata if provided
    if visa_type.present?
      scope = scope.where("metadata->>'visa_type' = ? OR metadata->>'visa_type' IS NULL", visa_type)
    end

    if rfe_category.present?
      scope = scope.where("metadata->>'rfe_category' = ? OR metadata->>'rfe_category' IS NULL", rfe_category)
    end

    results = scope.nearest_neighbors(:embedding, query_vector, distance: :cosine).first(limit)

    results.map do |embedding|
      {
        content: embedding.content,
        metadata: embedding.metadata,
        distance: embedding.neighbor_distance
      }
    end
  rescue => e
    Rails.logger.error("RagRetrievalService: Error retrieving context: #{e.message}")
    []
  end

  private

  def generate_embedding(text)
    client = OpenAI::Client.new

    response = client.embeddings(
      parameters: {
        model: MODEL,
        input: text.truncate(8000)
      }
    )

    response.dig("data", 0, "embedding")
  rescue Faraday::Error => e
    Rails.logger.error("RagRetrievalService: OpenAI embedding API error: #{e.message}")
    nil
  end
end
