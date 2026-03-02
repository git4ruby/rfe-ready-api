require "rails_helper"

RSpec.describe TenantPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, tenant)
      end
    end
  end

  permissions :update? do
    it "permits admin" do
      expect(subject).to permit(admin, tenant)
    end

    it "denies attorney" do
      expect(subject).not_to permit(attorney, tenant)
    end

    it "denies paralegal" do
      expect(subject).not_to permit(paralegal, tenant)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, tenant)
    end
  end
end
