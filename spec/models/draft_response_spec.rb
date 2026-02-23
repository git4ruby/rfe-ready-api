require "rails_helper"

RSpec.describe DraftResponse, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:case).class_name("RfeCase") }
    it { is_expected.to belong_to(:rfe_section) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_prefix(:response).with_values(draft: 0, editing: 1, reviewed: 2, approved: 3) }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
    let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }

    describe ".ordered" do
      it "orders by position" do
        draft_b = create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section, position: 2)
        draft_a = create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section, position: 1)

        expect(DraftResponse.ordered).to eq([draft_a, draft_b])
      end
    end

    describe ".approved" do
      it "returns only approved drafts" do
        approved = create(:draft_response, :approved, tenant: tenant, case: rfe_case, rfe_section: section)
        pending = create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section)

        expect(DraftResponse.approved).to include(approved)
        expect(DraftResponse.approved).not_to include(pending)
      end
    end
  end

  describe "#approve!" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
    let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }
    let(:draft) { create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section, ai_generated_content: "AI content", edited_content: "Edited content") }

    it "sets status to approved" do
      draft.approve!
      expect(draft.reload.status).to eq("approved")
    end

    it "uses edited_content as final_content when present" do
      draft.approve!
      expect(draft.reload.final_content).to eq("Edited content")
    end

    it "uses ai_generated_content when edited_content is blank" do
      draft.update!(edited_content: nil)
      draft.approve!
      expect(draft.reload.final_content).to eq("AI content")
    end

    it "stores attorney feedback" do
      draft.approve!(feedback: "Great work")
      expect(draft.reload.attorney_feedback).to eq("Great work")
    end
  end
end
