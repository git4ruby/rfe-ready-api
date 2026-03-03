require "rails_helper"

RSpec.describe CommentPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:comment) { create(:comment, tenant: tenant, case: rfe_case, user: attorney) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :index?, :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, comment)
      end
    end
  end

  permissions :create? do
    it "permits admin, attorney, paralegal" do
      [ admin, attorney, paralegal ].each do |user|
        expect(subject).to permit(user, comment)
      end
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, comment)
    end
  end

  permissions :update?, :destroy? do
    context "when user is admin" do
      it "permits admin regardless of authorship" do
        expect(subject).to permit(admin, comment)
      end
    end

    context "when user is the author" do
      it "permits the comment author" do
        expect(subject).to permit(attorney, comment)
      end
    end

    context "when user is not the author and not admin" do
      it "denies paralegal who is not the author" do
        expect(subject).not_to permit(paralegal, comment)
      end

      it "denies viewer" do
        expect(subject).not_to permit(viewer, comment)
      end
    end
  end
end
