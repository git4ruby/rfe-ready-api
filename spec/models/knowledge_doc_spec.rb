require "rails_helper"

RSpec.describe KnowledgeDoc, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:doc_type) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:uploaded_by).class_name("User") }
    it { is_expected.to have_many(:embeddings).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:doc_type).with_values(template: 0, sample_response: 1, regulation: 2, firm_knowledge: 3) }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }

    describe ".active" do
      it "returns only active documents" do
        active = create(:knowledge_doc, tenant: tenant, uploaded_by: user, is_active: true)
        inactive = create(:knowledge_doc, :inactive, tenant: tenant, uploaded_by: user)

        expect(KnowledgeDoc.active).to include(active)
        expect(KnowledgeDoc.active).not_to include(inactive)
      end
    end

    describe ".for_visa" do
      it "filters by visa type" do
        h1b = create(:knowledge_doc, tenant: tenant, uploaded_by: user, visa_type: "H-1B")
        l1 = create(:knowledge_doc, tenant: tenant, uploaded_by: user, visa_type: "L-1")

        expect(KnowledgeDoc.for_visa("H-1B")).to include(h1b)
        expect(KnowledgeDoc.for_visa("H-1B")).not_to include(l1)
      end
    end

    describe ".search" do
      it "searches by title" do
        doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user, title: "H-1B Specialty Occupation Guide")
        other = create(:knowledge_doc, tenant: tenant, uploaded_by: user, title: "L-1 Transfer")

        expect(KnowledgeDoc.search("specialty")).to include(doc)
        expect(KnowledgeDoc.search("specialty")).not_to include(other)
      end

      it "searches by content" do
        doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: "The beneficiary must hold a bachelor's degree")

        expect(KnowledgeDoc.search("bachelor")).to include(doc)
      end
    end
  end
end
