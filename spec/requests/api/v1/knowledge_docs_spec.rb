require "rails_helper"

RSpec.describe "Api::V1::KnowledgeDocs", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/knowledge_docs" do
    before do
      create_list(:knowledge_doc, 3, tenant: tenant, uploaded_by: admin)
    end

    it "returns paginated knowledge docs" do
      get "/api/v1/knowledge_docs", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(3)
      expect(body["meta"]["stats"]).to include("total_docs")
    end

    it "filters by doc_type" do
      create(:knowledge_doc, :template, tenant: tenant, uploaded_by: admin)

      get "/api/v1/knowledge_docs?doc_type=template", headers: authenticated_headers(admin)

      body = JSON.parse(response.body)
      body["data"].each do |doc|
        expect(doc["doc_type"]).to eq("template")
      end
    end

    it "searches by query" do
      create(:knowledge_doc, tenant: tenant, uploaded_by: admin, title: "H-1B Specialty Guide")

      get "/api/v1/knowledge_docs?q=specialty", headers: authenticated_headers(admin)

      body = JSON.parse(response.body)
      expect(body["data"].any? { |d| d["title"].include?("Specialty") }).to be true
    end
  end

  describe "POST /api/v1/knowledge_docs" do
    let(:valid_params) do
      {
        knowledge_doc: {
          title: "Test Document",
          doc_type: "regulation",
          content: "Some regulation content"
        }
      }
    end

    it "creates a doc as admin" do
      post "/api/v1/knowledge_docs", params: valid_params.to_json,
           headers: authenticated_headers(admin)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["title"]).to eq("Test Document")
    end

    it "denies viewer from creating" do
      post "/api/v1/knowledge_docs", params: valid_params.to_json,
           headers: authenticated_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/knowledge_docs/:id" do
    let!(:doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: admin) }

    it "deletes as admin" do
      expect {
        delete "/api/v1/knowledge_docs/#{doc.id}", headers: authenticated_headers(admin)
      }.to change(KnowledgeDoc, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "denies viewer from deleting" do
      delete "/api/v1/knowledge_docs/#{doc.id}", headers: authenticated_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
