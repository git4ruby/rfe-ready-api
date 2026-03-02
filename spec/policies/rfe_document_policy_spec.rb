require "rails_helper"

RSpec.describe RfeDocumentPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:document) { create(:rfe_document, tenant: tenant, case: rfe_case, uploaded_by: attorney) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, document)
      end
    end
  end

  permissions :create? do
    it "permits admin, attorney, paralegal" do
      [ admin, attorney, paralegal ].each do |user|
        expect(subject).to permit(user, document)
      end
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, document)
    end
  end

  permissions :destroy? do
    context "when user is admin" do
      it "permits admin regardless of uploader" do
        expect(subject).to permit(admin, document)
      end
    end

    context "when user is the uploader" do
      it "permits the user who uploaded the document" do
        expect(subject).to permit(attorney, document)
      end
    end

    context "when user is not the uploader and not admin" do
      it "denies paralegal who did not upload the document" do
        expect(subject).not_to permit(paralegal, document)
      end

      it "denies viewer" do
        expect(subject).not_to permit(viewer, document)
      end
    end
  end

  describe "Scope" do
    it "returns all documents" do
      document # ensure created
      scope = RfeDocumentPolicy::Scope.new(viewer, RfeDocument).resolve
      expect(scope).to include(document)
    end
  end
end
