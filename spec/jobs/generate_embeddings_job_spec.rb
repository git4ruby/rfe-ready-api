require "rails_helper"

RSpec.describe GenerateEmbeddingsJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user) }

  describe "#perform" do
    it "calls EmbeddingService for the document" do
      service = instance_double(EmbeddingService, call: true)
      allow(EmbeddingService).to receive(:new).and_return(service)

      described_class.perform_now(doc.id, tenant.id)

      expect(EmbeddingService).to have_received(:new)
      expect(service).to have_received(:call)
    end

    it "discards if document not found" do
      expect {
        described_class.perform_now("00000000-0000-0000-0000-000000000000", tenant.id)
      }.not_to raise_error
    end
  end

  describe "queueing" do
    it "enqueues in the default queue" do
      expect {
        described_class.perform_later(doc.id, tenant.id)
      }.to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
