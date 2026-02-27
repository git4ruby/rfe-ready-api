require "rails_helper"

RSpec.describe SlackNotificationService, type: :service do
  let(:tenant) { create(:tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
    ActiveJob::Base.queue_adapter = :test
  end

  describe "#call" do
    it "queues SendSlackNotificationJob for matching active integrations" do
      integration = create(:slack_integration, tenant: tenant, events: ["case.created"], active: true)

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: { case_number: "RFE-001" }).call
      }.to have_enqueued_job(SendSlackNotificationJob).with(integration.id, "case.created", { case_number: "RFE-001" }.to_json)
    end

    it "does not queue for inactive integrations" do
      create(:slack_integration, :inactive, tenant: tenant, events: ["case.created"])

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: {}).call
      }.not_to have_enqueued_job(SendSlackNotificationJob)
    end

    it "does not queue for non-matching events" do
      create(:slack_integration, tenant: tenant, events: ["document.uploaded"], active: true)

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: {}).call
      }.not_to have_enqueued_job(SendSlackNotificationJob)
    end

    it "queues for multiple matching integrations" do
      create(:slack_integration, tenant: tenant, events: ["case.created"], active: true, webhook_url: "https://hooks.slack.com/services/T00/B00/aaa")
      create(:slack_integration, tenant: tenant, events: ["case.created"], active: true, webhook_url: "https://hooks.slack.com/services/T00/B00/bbb")

      expect {
        described_class.new(tenant: tenant, event: "case.created", payload: {}).call
      }.to have_enqueued_job(SendSlackNotificationJob).exactly(2).times
    end
  end
end
