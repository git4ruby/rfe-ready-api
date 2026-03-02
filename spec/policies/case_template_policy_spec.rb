require "rails_helper"

RSpec.describe CaseTemplatePolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:template) { create(:case_template, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  subject { described_class }

  permissions :index? do
    it "permits all roles" do
      [ admin, attorney, paralegal, viewer ].each do |user|
        expect(subject).to permit(user, template)
      end
    end
  end

  permissions :show? do
    it "permits admin" do
      expect(subject).to permit(admin, template)
    end

    it "permits attorney" do
      expect(subject).to permit(attorney, template)
    end

    it "permits paralegal" do
      expect(subject).to permit(paralegal, template)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, template)
    end
  end

  permissions :create?, :update?, :destroy? do
    it "permits admin" do
      expect(subject).to permit(admin, template)
    end

    it "denies attorney" do
      expect(subject).not_to permit(attorney, template)
    end

    it "denies paralegal" do
      expect(subject).not_to permit(paralegal, template)
    end

    it "denies viewer" do
      expect(subject).not_to permit(viewer, template)
    end
  end

  describe "Scope" do
    it "returns all case templates" do
      template # ensure created
      scope = CaseTemplatePolicy::Scope.new(viewer, CaseTemplate).resolve
      expect(scope).to include(template)
    end
  end
end
