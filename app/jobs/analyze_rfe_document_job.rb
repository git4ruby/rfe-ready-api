class AnalyzeRfeDocumentJob < ApplicationJob
  queue_as :default

  retry_on Faraday::Error, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(case_id, tenant_id)
    ActsAsTenant.with_tenant(Tenant.find(tenant_id)) do
      RfeAnalysisService.new(case_id).call
    end
  end
end
