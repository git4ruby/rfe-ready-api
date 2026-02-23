require "rails_helper"

RSpec.describe RfeSection, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:section_type) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:case).class_name("RfeCase") }
    it { is_expected.to belong_to(:rfe_document).optional }
    it { is_expected.to have_many(:evidence_checklists).dependent(:destroy) }
    it { is_expected.to have_many(:draft_responses).dependent(:destroy) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:section_type).with_values(
        general: 0, specialty_occupation: 1, employer_employee: 2, beneficiary_qualifications: 3
      )
    }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

    describe ".ordered" do
      it "orders by position" do
        section_b = create(:rfe_section, tenant: tenant, case: rfe_case, position: 2)
        section_a = create(:rfe_section, tenant: tenant, case: rfe_case, position: 1)

        expect(RfeSection.ordered).to eq([section_a, section_b])
      end
    end

    describe ".high_confidence" do
      it "returns sections with confidence >= 0.8" do
        high = create(:rfe_section, :high_confidence, tenant: tenant, case: rfe_case)
        low = create(:rfe_section, :low_confidence, tenant: tenant, case: rfe_case)

        expect(RfeSection.high_confidence).to include(high)
        expect(RfeSection.high_confidence).not_to include(low)
      end
    end
  end
end
