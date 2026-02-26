require "rails_helper"

RSpec.describe WebhookDeliveryService, type: :service do
  let(:tenant) { create(:tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
    ActiveJob::Base.queue_adapter = :test
  end

  describe "#call" do
    it "queues DeliverWebhookJob for matching active webhooks" do
      webhook = create(:webhook, tenant: tenant, events: ["case.created"], active: true)

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: { id: "abc" }).call
      }.to have_enqueued_job(DeliverWebhookJob).with(webhook.id, "case.created", { id: "abc" }.to_json)
    end

    it "does not queue for inactive webhooks" do
      create(:webhook, :inactive, tenant: tenant, events: ["case.created"])

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: { id: "abc" }).call
      }.not_to have_enqueued_job(DeliverWebhookJob)
    end

    it "does not queue for webhooks without matching event" do
      create(:webhook, tenant: tenant, events: ["document.uploaded"], active: true)

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: { id: "abc" }).call
      }.not_to have_enqueued_job(DeliverWebhookJob)
    end

    it "queues for multiple matching webhooks" do
      webhook1 = create(:webhook, tenant: tenant, events: ["case.created"], active: true, url: "https://example.com/hook1")
      webhook2 = create(:webhook, tenant: tenant, events: ["case.created", "case.updated"], active: true, url: "https://example.com/hook2")

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: { id: "abc" }).call
      }.to have_enqueued_job(DeliverWebhookJob).exactly(2).times
    end

    it "does not queue for webhooks belonging to a different tenant" do
      other_tenant = create(:tenant)
      ActsAsTenant.with_tenant(other_tenant) do
        create(:webhook, tenant: other_tenant, events: ["case.created"], active: true)
      end

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: { id: "abc" }).call
      }.not_to have_enqueued_job(DeliverWebhookJob)
    end
  end
end
