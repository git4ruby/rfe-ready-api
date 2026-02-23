require "rails_helper"

RSpec.describe FeatureFlag, type: :model do
  describe "validations" do
    subject { build(:feature_flag) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:tenant_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant) }
  end

  describe ".enabled?" do
    let(:tenant) { create(:tenant, plan: :professional) }
    let(:admin_user) { create(:user, :admin, tenant: tenant) }
    let(:attorney_user) { create(:user, :attorney, tenant: tenant) }
    let(:viewer_user) { create(:user, :viewer, tenant: tenant) }

    it "returns true for enabled flag with no restrictions" do
      create(:feature_flag, tenant: tenant, name: "ai_analysis", enabled: true)
      expect(FeatureFlag.enabled?("ai_analysis", admin_user)).to be true
    end

    it "returns false for disabled flag" do
      create(:feature_flag, tenant: tenant, name: "ai_analysis", enabled: false)
      expect(FeatureFlag.enabled?("ai_analysis", admin_user)).to be false
    end

    it "returns false for non-existent flag" do
      expect(FeatureFlag.enabled?("nonexistent", admin_user)).to be false
    end

    context "with role restrictions" do
      before do
        create(:feature_flag, tenant: tenant, name: "bulk_actions", enabled: true, allowed_roles: %w[admin])
      end

      it "allows matching role" do
        expect(FeatureFlag.enabled?("bulk_actions", admin_user)).to be true
      end

      it "denies non-matching role" do
        expect(FeatureFlag.enabled?("bulk_actions", viewer_user)).to be false
      end
    end

    context "with plan restrictions" do
      let(:trial_tenant) { create(:tenant, plan: :trial) }
      let(:trial_user) { create(:user, :admin, tenant: trial_tenant) }

      before do
        create(:feature_flag, tenant: tenant, name: "export", enabled: true, allowed_plans: %w[professional enterprise])
        create(:feature_flag, tenant: trial_tenant, name: "export", enabled: true, allowed_plans: %w[professional enterprise])
      end

      it "allows matching plan" do
        expect(FeatureFlag.enabled?("export", admin_user)).to be true
      end

      it "denies non-matching plan" do
        expect(FeatureFlag.enabled?("export", trial_user)).to be false
      end
    end
  end

  describe ".seed_defaults" do
    let(:tenant) { create(:tenant) }

    it "creates default feature flags" do
      expect { FeatureFlag.seed_defaults(tenant) }.to change(FeatureFlag, :count).by(6)
    end

    it "is idempotent" do
      FeatureFlag.seed_defaults(tenant)
      expect { FeatureFlag.seed_defaults(tenant) }.not_to change(FeatureFlag, :count)
    end

    it "creates known flag names" do
      FeatureFlag.seed_defaults(tenant)
      names = FeatureFlag.where(tenant: tenant).pluck(:name)
      expect(names).to include("ai_analysis", "bulk_actions", "export_pdf", "knowledge_base", "draft_generation", "audit_log_export")
    end
  end
end
