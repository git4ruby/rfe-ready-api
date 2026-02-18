class GenerateEmbeddingsJob < ApplicationJob
  queue_as :default

  retry_on Faraday::Error, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(knowledge_doc_id, tenant_id)
    ActsAsTenant.with_tenant(Tenant.find(tenant_id)) do
      doc = KnowledgeDoc.find(knowledge_doc_id)
      EmbeddingService.new(doc).call
    end
  end
end
