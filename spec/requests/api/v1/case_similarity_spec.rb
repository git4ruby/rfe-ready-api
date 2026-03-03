require "rails_helper"

RSpec.describe "Api::V1::Cases#similar", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }
  let(:headers) { auth_headers(user) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

  before do
    service = instance_double(CaseSimilarityService)
    allow(CaseSimilarityService).to receive(:new).and_return(service)
    allow(service).to receive(:call).and_return(similar_results)
  end

  let(:similar_results) do
    [
      {
        id: SecureRandom.uuid,
        case_number: "RFE-2025-002",
        petitioner_name: "Similar Corp",
        visa_type: "H-1B",
        status: "review",
        similarity_score: 0.87,
        matched_content: "Specialty occupation requirements..."
      }
    ]
  end

  describe "GET /api/v1/cases/:id/similar" do
    it "returns similar cases" do
      get "/api/v1/cases/#{rfe_case.id}/similar", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["case_number"]).to eq("RFE-2025-002")
      expect(body["data"].first["similarity_score"]).to eq(0.87)
    end

    it "passes limit parameter to the service" do
      get "/api/v1/cases/#{rfe_case.id}/similar",
        params: { limit: 3 },
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(CaseSimilarityService).to have_received(:new).with(
        hash_including(limit: 3)
      )
    end

    it "clamps limit between 1 and 20" do
      get "/api/v1/cases/#{rfe_case.id}/similar",
        params: { limit: 100 },
        headers: headers

      expect(CaseSimilarityService).to have_received(:new).with(
        hash_including(limit: 20)
      )
    end

    it "returns 401 without authentication" do
      get "/api/v1/cases/#{rfe_case.id}/similar"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for non-existent case" do
      get "/api/v1/cases/#{SecureRandom.uuid}/similar", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
