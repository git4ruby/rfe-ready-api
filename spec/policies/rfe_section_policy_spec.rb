require "rails_helper"

RSpec.describe RfeSectionPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, section)
      end
    end
  end

  permissions :update?, :reclassify? do
    it "permits admin, attorney, paralegal" do
      [ admin, attorney, paralegal ].each do |user|
        expect(subject).to permit(user, section)
      end
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, section)
    end
  end
end
