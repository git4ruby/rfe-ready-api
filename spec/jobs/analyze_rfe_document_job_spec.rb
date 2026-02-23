require "rails_helper"

RSpec.describe AnalyzeRfeDocumentJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

  describe "#perform" do
    it "sets tenant and calls RfeAnalysisService" do
      service = instance_double(RfeAnalysisService, call: true)
      allow(RfeAnalysisService).to receive(:new).with(rfe_case.id).and_return(service)

      described_class.perform_now(rfe_case.id, tenant.id)

      expect(RfeAnalysisService).to have_received(:new).with(rfe_case.id)
      expect(service).to have_received(:call)
    end

    it "discards if record not found" do
      expect {
        described_class.perform_now("00000000-0000-0000-0000-000000000000", tenant.id)
      }.not_to raise_error
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
