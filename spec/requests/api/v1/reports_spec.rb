require "rails_helper"

RSpec.describe "Api::V1::Reports", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/reports/dashboard" do
    before do
      create_list(:rfe_case, 3, tenant: tenant, created_by: admin, visa_type: "H-1B")
      create(:rfe_case, tenant: tenant, created_by: admin, visa_type: "L-1", status: "responded")
    end

    it "returns 200 with report data for admin" do
      get "/api/v1/reports/dashboard", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      data = body["data"]

      expect(data).to have_key("case_stats")
      expect(data).to have_key("timeline")
      expect(data).to have_key("evidence_stats")
      expect(data).to have_key("draft_stats")
      expect(data).to have_key("attorney_stats")
    end

    it "returns correct case stats structure" do
      get "/api/v1/reports/dashboard", headers: auth_headers(admin)

      body = JSON.parse(response.body)
      case_stats = body["data"]["case_stats"]

      expect(case_stats["total"]).to eq(4)
      expect(case_stats["by_status"]).to be_a(Hash)
      expect(case_stats["by_visa_type"]).to be_a(Hash)
      expect(case_stats).to have_key("avg_days_to_respond")
      expect(case_stats).to have_key("completion_rate")
    end

    it "passes period parameter" do
      get "/api/v1/reports/dashboard?period=7d", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
    end

    it "defaults to 30d period" do
      get "/api/v1/reports/dashboard", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
    end

    it "allows attorney access" do
      get "/api/v1/reports/dashboard", headers: auth_headers(attorney)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to have_key("case_stats")
    end

    it "returns 401 without authentication" do
      get "/api/v1/reports/dashboard"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for paralegal role" do
      get "/api/v1/reports/dashboard", headers: auth_headers(paralegal)

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Forbidden")
    end

    it "returns 403 for viewer role" do
      get "/api/v1/reports/dashboard", headers: auth_headers(viewer)

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Forbidden")
    end

    it "accepts all period values" do
      %w[7d 30d 90d all].each do |period|
        get "/api/v1/reports/dashboard?period=#{period}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
