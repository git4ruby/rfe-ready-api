require "rails_helper"

RSpec.describe "Api::V1::Dashboard", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/dashboard" do
    before do
      create_list(:rfe_case, 3, tenant: tenant, created_by: user)
      create(:knowledge_doc, tenant: tenant, uploaded_by: user)
    end

    it "returns dashboard stats" do
      get "/api/v1/dashboard", headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["total_cases"]).to eq(3)
      expect(body["data"]["cases_by_status"]).to be_a(Hash)
      expect(body["data"]["knowledge_stats"]["total_docs"]).to eq(1)
    end

    it "accepts period parameter" do
      get "/api/v1/dashboard?period=7d", headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
    end

    it "returns 401 without authentication" do
      get "/api/v1/dashboard"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
