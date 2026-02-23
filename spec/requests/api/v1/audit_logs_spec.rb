require "rails_helper"

RSpec.describe "Api::V1::AuditLogs", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/audit_logs" do
    before do
      rfe_case = create(:rfe_case, tenant: tenant, created_by: admin)
      create_list(:audit_log, 3, tenant: tenant, user: admin, auditable: rfe_case)
    end

    it "returns audit logs for admin" do
      get "/api/v1/audit_logs", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
    end

    it "denies non-admin users" do
      get "/api/v1/audit_logs", headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end

    it "filters by action_type" do
      get "/api/v1/audit_logs?action_type=create", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/audit_logs/export" do
    before do
      rfe_case = create(:rfe_case, tenant: tenant, created_by: admin)
      create(:audit_log, tenant: tenant, user: admin, auditable: rfe_case)
    end

    it "exports CSV by default" do
      get "/api/v1/audit_logs/export", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end

    it "exports PDF when requested" do
      get "/api/v1/audit_logs/export?format_type=pdf", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/pdf")
    end
  end
end
