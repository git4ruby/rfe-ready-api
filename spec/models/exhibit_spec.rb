require "rails_helper"

RSpec.describe Exhibit, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }

    it "validates uniqueness of label within a case" do
      user = create(:user, tenant: tenant)
      rfe_case = create(:rfe_case, tenant: tenant, created_by: user)
      create(:exhibit, tenant: tenant, case: rfe_case, label: "Exhibit A")

      duplicate = build(:exhibit, tenant: tenant, case: rfe_case, label: "Exhibit A")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:label]).to include("has already been taken")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:case).class_name("RfeCase") }
    it { is_expected.to belong_to(:rfe_document).optional }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

    describe ".ordered" do
      it "orders by position" do
        exhibit_b = create(:exhibit, tenant: tenant, case: rfe_case, position: 2)
        exhibit_a = create(:exhibit, tenant: tenant, case: rfe_case, position: 1)

        expect(Exhibit.ordered).to eq([ exhibit_a, exhibit_b ])
      end
    end
  end
end
