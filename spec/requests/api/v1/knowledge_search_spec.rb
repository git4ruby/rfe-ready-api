require "rails_helper"

RSpec.describe "Api::V1::KnowledgeSearch", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:headers) { auth_headers(user) }

  let(:search_results) do
    {
      results: [
        {
          content: "Sample knowledge content about H-1B",
          relevance_score: 0.85,
          title: "H-1B Regulation",
          doc_type: "regulation",
          visa_type: "H-1B",
          knowledge_doc_id: SecureRandom.uuid
        }
      ],
      query: "H-1B specialty",
      total: 1
    }
  end

  before do
    service = instance_double(KnowledgeSearchService)
    allow(KnowledgeSearchService).to receive(:new).and_return(service)
    allow(service).to receive(:call).and_return(search_results)
  end

  describe "GET /api/v1/knowledge/search" do
    it "returns search results" do
      get "/api/v1/knowledge/search", params: { q: "H-1B specialty" }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["results"].size).to eq(1)
      expect(body["data"]["query"]).to eq("H-1B specialty")
      expect(body["data"]["total"]).to eq(1)

      result = body["data"]["results"].first
      expect(result["content"]).to include("H-1B")
      expect(result["relevance_score"]).to eq(0.85)
    end

    it "passes visa_type filter to the service" do
      get "/api/v1/knowledge/search",
        params: { q: "specialty", visa_type: "H-1B" },
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(KnowledgeSearchService).to have_received(:new).with(
        hash_including(visa_type: "H-1B")
      )
    end

    it "passes limit parameter clamped between 1 and 50" do
      get "/api/v1/knowledge/search",
        params: { q: "test", limit: 100 },
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(KnowledgeSearchService).to have_received(:new).with(
        hash_including(limit: 50)
      )
    end

    it "defaults limit to 10" do
      get "/api/v1/knowledge/search",
        params: { q: "test" },
        headers: headers

      expect(KnowledgeSearchService).to have_received(:new).with(
        hash_including(limit: 10)
      )
    end

    it "strips whitespace from query" do
      get "/api/v1/knowledge/search",
        params: { q: "  H-1B specialty  " },
        headers: headers

      expect(KnowledgeSearchService).to have_received(:new).with(
        hash_including(query: "H-1B specialty")
      )
    end

    it "returns empty results for blank query" do
      empty_results = { results: [], query: "" }
      allow(KnowledgeSearchService).to receive(:new).and_call_original
      rag_service = instance_double(RagRetrievalService)
      allow(RagRetrievalService).to receive(:new).and_return(rag_service)
      allow(rag_service).to receive(:call).and_return([])

      get "/api/v1/knowledge/search", params: { q: "" }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["results"]).to eq([])
    end

    context "without authentication" do
      it "returns 401" do
        get "/api/v1/knowledge/search", params: { q: "test" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with viewer role" do
      let(:viewer) { create(:user, tenant: tenant, role: "viewer") }
      let(:viewer_headers) { auth_headers(viewer) }

      it "allows search for all roles" do
        get "/api/v1/knowledge/search",
          params: { q: "test" },
          headers: viewer_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
