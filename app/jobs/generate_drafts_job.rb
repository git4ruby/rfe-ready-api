class GenerateDraftsJob < ApplicationJob
  queue_as :default

  retry_on Faraday::Error, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(case_id, tenant_id, section_id: nil)
    ActsAsTenant.with_tenant(Tenant.find(tenant_id)) do
      service = DraftGenerationService.new(case_id)

      if section_id
        section = RfeSection.find(section_id)
        service.regenerate_for_section(section)
      else
        service.call
      end
    end
  end
end
