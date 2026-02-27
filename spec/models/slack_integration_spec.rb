require "rails_helper"

RSpec.describe SlackIntegration, type: :model do
  let(:tenant) { create(:tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "validations" do
    it "is valid with valid attributes" do
      integration = build(:slack_integration, tenant: tenant)
      expect(integration).to be_valid
    end

    it "validates webhook_url presence" do
      integration = build(:slack_integration, tenant: tenant, webhook_url: nil)
      expect(integration).not_to be_valid
      expect(integration.errors[:webhook_url]).to include("can't be blank")
    end

    it "validates webhook_url is a Slack URL" do
      integration = build(:slack_integration, tenant: tenant, webhook_url: "https://example.com/hook")
      expect(integration).not_to be_valid
      expect(integration.errors[:webhook_url]).to include("must be a valid Slack webhook URL")
    end

    it "accepts valid Slack webhook URLs" do
      integration = build(:slack_integration, tenant: tenant, webhook_url: "https://hooks.slack.com/services/T00/B00/xxxx")
      expect(integration).to be_valid
    end

    it "validates events presence" do
      integration = build(:slack_integration, tenant: tenant, events: [])
      expect(integration).not_to be_valid
    end

    it "validates events are supported" do
      integration = build(:slack_integration, tenant: tenant, events: ["invalid.event"])
      expect(integration).not_to be_valid
      expect(integration.errors[:events].first).to include("invalid.event")
    end

    it "allows all supported events" do
      integration = build(:slack_integration, tenant: tenant, events: SlackIntegration::SUPPORTED_EVENTS)
      expect(integration).to be_valid
    end
  end
end
