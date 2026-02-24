require "rails_helper"

RSpec.describe KnowledgeDocPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: admin) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :show? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, doc)
      end
    end
  end

  permissions :create?, :update? do
    it "permits admin, attorney, paralegal" do
      [ admin, attorney, paralegal ].each do |user|
        expect(subject).to permit(user, doc)
      end
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, doc)
    end
  end

  permissions :destroy? do
    it "permits admin only" do
      expect(subject).to permit(admin, doc)
    end

    it "denies attorney" do
      expect(subject).not_to permit(attorney, doc)
    end

    it "denies paralegal" do
      expect(subject).not_to permit(paralegal, doc)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, doc)
    end
  end
end
