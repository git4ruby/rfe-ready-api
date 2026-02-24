require "rails_helper"

RSpec.describe RfeCasePolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, rfe_case)
      end
    end
  end

  permissions :create?, :update? do
    it "permits admin" do
      expect(subject).to permit(admin, rfe_case)
    end

    it "permits attorney" do
      expect(subject).to permit(attorney, rfe_case)
    end

    it "permits paralegal" do
      expect(subject).to permit(paralegal, rfe_case)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, rfe_case)
    end
  end

  permissions :destroy? do
    it "permits admin" do
      expect(subject).to permit(admin, rfe_case)
    end

    it "denies attorney" do
      expect(subject).not_to permit(attorney, rfe_case)
    end

    it "denies paralegal" do
      expect(subject).not_to permit(paralegal, rfe_case)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, rfe_case)
    end
  end

  permissions :start_analysis?, :archive? do
    it "permits admin, attorney, paralegal" do
      [ admin, attorney, paralegal ].each do |user|
        expect(subject).to permit(user, rfe_case)
      end
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, rfe_case)
    end
  end

  permissions :assign_attorney?, :mark_reviewed?, :mark_responded?, :export? do
    it "permits admin" do
      expect(subject).to permit(admin, rfe_case)
    end

    it "permits attorney" do
      expect(subject).to permit(attorney, rfe_case)
    end

    it "denies paralegal" do
      expect(subject).not_to permit(paralegal, rfe_case)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, rfe_case)
    end
  end

  permissions :reopen? do
    it "permits admin only" do
      expect(subject).to permit(admin, rfe_case)
    end

    it "denies attorney" do
      expect(subject).not_to permit(attorney, rfe_case)
    end

    it "denies paralegal" do
      expect(subject).not_to permit(paralegal, rfe_case)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, rfe_case)
    end
  end
end
