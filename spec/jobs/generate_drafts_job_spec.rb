require "rails_helper"

RSpec.describe GenerateDraftsJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "#perform" do
    it "calls DraftGenerationService for all sections" do
      service = instance_double(DraftGenerationService, call: true)
      allow(DraftGenerationService).to receive(:new).with(rfe_case.id).and_return(service)

      described_class.perform_now(rfe_case.id, tenant.id)

      expect(DraftGenerationService).to have_received(:new).with(rfe_case.id)
      expect(service).to have_received(:call)
    end

    it "regenerates for a specific section when section_id is provided" do
      section = create(:rfe_section, tenant: tenant, case: rfe_case)
      service = instance_double(DraftGenerationService, regenerate_for_section: true)
      allow(DraftGenerationService).to receive(:new).with(rfe_case.id).and_return(service)

      described_class.perform_now(rfe_case.id, tenant.id, section_id: section.id)

      expect(service).to have_received(:regenerate_for_section).with(section)
    end
  end

  describe "queueing" do
    it "enqueues in the default queue" do
      expect {
        described_class.perform_later(rfe_case.id, tenant.id)
      }.to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
