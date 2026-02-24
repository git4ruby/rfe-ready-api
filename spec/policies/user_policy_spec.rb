require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:other_tenant) { create(:tenant) }
  let(:other_user) { create(:user, tenant: other_tenant) }

  subject { described_class }

  permissions :index? do
    it "permits admin" do
      expect(subject).to permit(admin, User)
    end

    it "denies non-admin" do
      expect(subject).not_to permit(attorney, User)
      expect(subject).not_to permit(viewer, User)
    end
  end

  permissions :create? do
    it "permits admin" do
      expect(subject).to permit(admin, User.new(tenant: tenant))
    end

    it "denies non-admin" do
      expect(subject).not_to permit(attorney, User.new(tenant: tenant))
    end
  end

  permissions :update? do
    it "permits admin for same-tenant user" do
      expect(subject).to permit(admin, attorney)
    end

    it "denies admin from updating self" do
      expect(subject).not_to permit(admin, admin)
    end

    it "denies admin for other-tenant user" do
      expect(subject).not_to permit(admin, other_user)
    end

    it "denies non-admin" do
      expect(subject).not_to permit(attorney, viewer)
    end
  end

  permissions :destroy? do
    it "permits admin for same-tenant user" do
      expect(subject).to permit(admin, attorney)
    end

    it "denies admin from deleting self" do
      expect(subject).not_to permit(admin, admin)
    end

    it "denies non-admin" do
      expect(subject).not_to permit(attorney, viewer)
    end
  end

  permissions :resend_invitation? do
    it "permits admin for same-tenant user" do
      expect(subject).to permit(admin, attorney)
    end

    it "denies non-admin" do
      expect(subject).not_to permit(attorney, viewer)
    end
  end

  describe "Scope" do
    it "returns users in the same tenant" do
      users = UserPolicy::Scope.new(admin, User).resolve
      expect(users.pluck(:tenant_id).uniq).to eq([ tenant.id ])
    end
  end
end
