require "rails_helper"

RSpec.describe Embedding, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:content) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:embeddable) }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }

    describe ".for_type" do
      it "filters by embeddable type" do
        doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user)
        embedding = Embedding.create!(tenant: tenant, embeddable: doc, content: "test content")

        expect(Embedding.for_type("KnowledgeDoc")).to include(embedding)
        expect(Embedding.for_type("RfeCase")).not_to include(embedding)
      end
    end
  end
end
