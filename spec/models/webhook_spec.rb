require "rails_helper"

RSpec.describe Webhook, type: :model do
  let(:tenant) { create(:tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
  end

  describe "validations" do
    it "validates url presence" do
      webhook = build(:webhook, tenant: tenant, url: nil)
      expect(webhook).not_to be_valid
      expect(webhook.errors[:url]).to include("can't be blank")
    end

    it "validates url format with valid HTTP URL" do
      webhook = build(:webhook, tenant: tenant, url: "https://example.com/hook")
      expect(webhook).to be_valid
    end

    it "validates url format rejects invalid URLs" do
      webhook = build(:webhook, tenant: tenant, url: "not-a-url")
      expect(webhook).not_to be_valid
      expect(webhook.errors[:url]).to include("must be a valid HTTP(S) URL")
    end

    it "validates url format rejects ftp URLs" do
      webhook = build(:webhook, tenant: tenant, url: "ftp://example.com/hook")
      expect(webhook).not_to be_valid
      expect(webhook.errors[:url]).to include("must be a valid HTTP(S) URL")
    end

    it "validates events presence" do
      webhook = build(:webhook, tenant: tenant, events: [])
      expect(webhook).not_to be_valid
      expect(webhook.errors[:events]).to include("can't be blank")
    end

    it "validates events are supported" do
      webhook = build(:webhook, tenant: tenant, events: ["case.created"])
      expect(webhook).to be_valid
    end

    it "rejects invalid events" do
      webhook = build(:webhook, tenant: tenant, events: ["invalid.event"])
      expect(webhook).not_to be_valid
      expect(webhook.errors[:events].first).to include("contains unsupported events: invalid.event")
    end

    it "rejects a mix of valid and invalid events" do
      webhook = build(:webhook, tenant: tenant, events: ["case.created", "bogus.event"])
      expect(webhook).not_to be_valid
      expect(webhook.errors[:events].first).to include("bogus.event")
    end

    it "allows multiple valid events" do
      webhook = build(:webhook, tenant: tenant, events: ["case.created", "case.updated", "document.uploaded"])
      expect(webhook).to be_valid
    end

    it "allows all supported events" do
      webhook = build(:webhook, tenant: tenant, events: Webhook::SUPPORTED_EVENTS)
      expect(webhook).to be_valid
    end
  end

  describe "SUPPORTED_EVENTS" do
    it "includes expected event types" do
      expect(Webhook::SUPPORTED_EVENTS).to include(
        "case.created", "case.updated", "case.status_changed", "case.archived",
        "document.uploaded", "document.deleted",
        "draft.approved", "draft.regenerated"
      )
    end
  end
end
