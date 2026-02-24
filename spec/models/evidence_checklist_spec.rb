require "rails_helper"

RSpec.describe EvidenceChecklist, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:document_name) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:case).class_name("RfeCase") }
    it { is_expected.to belong_to(:rfe_section) }
    it { is_expected.to belong_to(:linked_document).class_name("RfeDocument").optional }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:priority).with_values(required: 0, recommended: 1, optional: 2) }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
    let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }

    describe ".ordered" do
      it "orders by position" do
        item_b = create(:evidence_checklist, tenant: tenant, case: rfe_case, rfe_section: section, position: 2)
        item_a = create(:evidence_checklist, tenant: tenant, case: rfe_case, rfe_section: section, position: 1)

        expect(EvidenceChecklist.ordered).to eq([ item_a, item_b ])
      end
    end

    describe ".collected" do
      it "returns only collected items" do
        collected = create(:evidence_checklist, :collected, tenant: tenant, case: rfe_case, rfe_section: section)
        uncollected = create(:evidence_checklist, tenant: tenant, case: rfe_case, rfe_section: section)

        expect(EvidenceChecklist.collected).to include(collected)
        expect(EvidenceChecklist.collected).not_to include(uncollected)
      end
    end

    describe ".uncollected" do
      it "returns only uncollected items" do
        collected = create(:evidence_checklist, :collected, tenant: tenant, case: rfe_case, rfe_section: section)
        uncollected = create(:evidence_checklist, tenant: tenant, case: rfe_case, rfe_section: section)

        expect(EvidenceChecklist.uncollected).to include(uncollected)
        expect(EvidenceChecklist.uncollected).not_to include(collected)
      end
    end
  end

  describe "#toggle_collected!" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
    let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }

    it "toggles from uncollected to collected" do
      item = create(:evidence_checklist, tenant: tenant, case: rfe_case, rfe_section: section, is_collected: false)
      item.toggle_collected!
      expect(item.reload.is_collected).to be true
    end

    it "toggles from collected to uncollected" do
      item = create(:evidence_checklist, :collected, tenant: tenant, case: rfe_case, rfe_section: section)
      item.toggle_collected!
      expect(item.reload.is_collected).to be false
    end
  end
end
