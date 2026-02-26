class KnowledgeSearchService
  DEFAULT_LIMIT = 10

  attr_reader :query, :tenant, :visa_type, :limit

  def initialize(query:, tenant:, visa_type: nil, limit: DEFAULT_LIMIT)
    @query = query
    @tenant = tenant
    @visa_type = visa_type
    @limit = limit
  end

  def call
    return { results: [], query: query } if query.blank?

    rag_results = RagRetrievalService.new(
      query: query,
      tenant: tenant,
      visa_type: visa_type,
      limit: limit
    ).call

    results = rag_results.map do |result|
      doc_id = find_knowledge_doc_id(result)
      doc = doc_id ? KnowledgeDoc.find_by(id: doc_id) : nil

      {
        content: result[:content],
        relevance_score: (1.0 - result[:distance]).round(4),
        title: result.dig(:metadata, "title") || doc&.title,
        doc_type: result.dig(:metadata, "doc_type") || doc&.doc_type,
        visa_type: result.dig(:metadata, "visa_type"),
        knowledge_doc_id: doc_id
      }
    end

    { results: results, query: query, total: results.size }
  end

  private

  def find_knowledge_doc_id(result)
    # Result metadata may contain the doc reference
    result.dig(:metadata, "knowledge_doc_id")
  end
end
