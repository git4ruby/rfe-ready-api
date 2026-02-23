require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:role) }

    context "when attorney" do
      subject { build(:user, :attorney, bar_number: nil) }
      it { is_expected.to validate_presence_of(:bar_number) }
    end

    context "when not attorney" do
      subject { build(:user, :admin) }
      it { is_expected.not_to validate_presence_of(:bar_number) }
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant) }
    it { is_expected.to have_many(:created_cases).class_name("RfeCase").dependent(:nullify) }
    it { is_expected.to have_many(:assigned_cases).class_name("RfeCase").dependent(:nullify) }
    it { is_expected.to have_many(:uploaded_documents).class_name("RfeDocument").dependent(:nullify) }
    it { is_expected.to have_many(:uploaded_knowledge_docs).class_name("KnowledgeDoc").dependent(:nullify) }
    it { is_expected.to have_many(:audit_logs).dependent(:nullify) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(admin: 0, attorney: 1, paralegal: 2, viewer: 3) }
    it { is_expected.to define_enum_for(:status).with_prefix(:account).with_values(active: 0, inactive: 1, invited: 2) }
  end

  describe "scopes" do
    let(:tenant) { create(:tenant) }
    let!(:active_user) { create(:user, tenant: tenant, status: :active) }
    let!(:inactive_user) { create(:user, :inactive, tenant: tenant) }

    describe ".active" do
      it "returns only active users" do
        expect(User.active).to include(active_user)
        expect(User.active).not_to include(inactive_user)
      end
    end
  end

  describe "#full_name" do
    it "returns first and last name" do
      user = build(:user, first_name: "John", last_name: "Doe")
      expect(user.full_name).to eq("John Doe")
    end
  end

  describe "#super_admin?" do
    it "returns true when is_super_admin is true" do
      user = build(:user, :super_admin)
      expect(user.super_admin?).to be true
    end

    it "returns false when is_super_admin is false" do
      user = build(:user)
      expect(user.super_admin?).to be false
    end
  end

  describe "#jwt_payload" do
    it "includes required fields" do
      user = create(:user)
      payload = user.jwt_payload
      expect(payload).to include("jti", "tenant_id", "role", "is_super_admin")
      expect(payload["tenant_id"]).to eq(user.tenant_id)
      expect(payload["role"]).to eq(user.role)
    end
  end

  describe "devise modules" do
    it "is database authenticatable" do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it "is jwt authenticatable" do
      expect(User.devise_modules).to include(:jwt_authenticatable)
    end

    it "is confirmable" do
      expect(User.devise_modules).to include(:confirmable)
    end

    it "is lockable" do
      expect(User.devise_modules).to include(:lockable)
    end
  end
end
