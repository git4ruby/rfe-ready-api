require "rails_helper"

RSpec.describe ExhibitPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:exhibit) { create(:exhibit, tenant: tenant, case: rfe_case) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, exhibit)
      end
    end
  end

  permissions :create?, :update?, :destroy? do
    it "permits admin, attorney, paralegal" do
      [ admin, attorney, paralegal ].each do |user|
        expect(subject).to permit(user, exhibit)
      end
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, exhibit)
    end
  end
end
