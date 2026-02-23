require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "validations" do
    subject { build(:tenant) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to allow_value("my-tenant-1").for(:slug) }
    it { is_expected.not_to allow_value("My Tenant").for(:slug) }
    it { is_expected.not_to allow_value("TENANT").for(:slug) }
    it { is_expected.not_to allow_value("tenant_1").for(:slug) }
  end

  describe "associations" do
    it { is_expected.to have_many(:users).dependent(:destroy) }
    it { is_expected.to have_many(:rfe_cases).dependent(:destroy) }
    it { is_expected.to have_many(:knowledge_docs).dependent(:destroy) }
    it { is_expected.to have_many(:embeddings).dependent(:destroy) }
    it { is_expected.to have_many(:audit_logs).dependent(:destroy) }
    it { is_expected.to have_many(:feature_flags).dependent(:destroy) }
    it { is_expected.to have_many(:backups).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:plan).with_values(trial: 0, basic: 1, professional: 2, enterprise: 3) }
    it { is_expected.to define_enum_for(:status).with_values(active: 0, suspended: 1, cancelled: 2) }
  end

  describe "scopes" do
    let!(:active_tenant) { create(:tenant, status: :active) }
    let!(:suspended_tenant) { create(:tenant, :suspended) }
    let!(:platform_tenant) { create(:tenant, :platform) }

    describe ".active" do
      it "returns only active tenants" do
        expect(Tenant.active).to include(active_tenant, platform_tenant)
        expect(Tenant.active).not_to include(suspended_tenant)
      end
    end

    describe ".real_tenants" do
      it "excludes the platform tenant" do
        expect(Tenant.real_tenants).to include(active_tenant)
        expect(Tenant.real_tenants).not_to include(platform_tenant)
      end
    end
  end

  describe ".platform_tenant" do
    it "returns the platform admin tenant" do
      platform = create(:tenant, :platform)
      expect(Tenant.platform_tenant).to eq(platform)
    end

    it "raises if platform tenant does not exist" do
      expect { Tenant.platform_tenant }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#platform_tenant?" do
    it "returns true for platform tenant" do
      tenant = build(:tenant, :platform)
      expect(tenant.platform_tenant?).to be true
    end

    it "returns false for regular tenant" do
      tenant = build(:tenant)
      expect(tenant.platform_tenant?).to be false
    end
  end

  describe "callbacks" do
    describe "#generate_slug" do
      it "generates slug from name if not provided" do
        tenant = create(:tenant, name: "My Law Firm", slug: nil)
        expect(tenant.slug).to eq("my-law-firm")
      end

      it "does not overwrite existing slug" do
        tenant = create(:tenant, name: "My Firm", slug: "custom-slug")
        expect(tenant.slug).to eq("custom-slug")
      end
    end
  end
end
