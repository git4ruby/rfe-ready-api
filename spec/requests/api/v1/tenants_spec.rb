require "rails_helper"

RSpec.describe "Api::V1::Tenants", type: :request do
  let(:tenant) { create(:tenant, name: "Acme Law Firm", data_retention_days: 90) }
  let(:admin_user) { create(:user, :admin, tenant: tenant) }
  let(:attorney_user) { create(:user, :attorney, tenant: tenant) }
  let(:viewer_user) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/tenant" do
    it "returns the current tenant data for an admin" do
      get "/api/v1/tenant", headers: authenticated_headers(admin_user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_present
      expect(body["data"]["name"]).to eq("Acme Law Firm")
    end

    it "returns the current tenant data for an attorney" do
      get "/api/v1/tenant", headers: authenticated_headers(attorney_user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["name"]).to eq("Acme Law Firm")
    end

    it "returns the current tenant data for a viewer" do
      get "/api/v1/tenant", headers: authenticated_headers(viewer_user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["name"]).to eq("Acme Law Firm")
    end

    it "returns 401 without authentication" do
      get "/api/v1/tenant"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/tenant" do
    context "as an admin" do
      it "updates the tenant name" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "Updated Law Firm" } }.to_json,
              headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["name"]).to eq("Updated Law Firm")
        expect(tenant.reload.name).to eq("Updated Law Firm")
      end

      it "updates data_retention_days" do
        patch "/api/v1/tenant",
              params: { tenant: { data_retention_days: 180 } }.to_json,
              headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        expect(tenant.reload.data_retention_days).to eq(180)
      end

      it "updates settings" do
        patch "/api/v1/tenant",
              params: { tenant: { settings: { theme: "dark", notifications: true } } }.to_json,
              headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["settings"]).to include("theme" => "dark")
      end

      it "returns 422 with invalid params" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "" } }.to_json,
              headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Validation failed.")
        expect(body["details"]).to be_present
      end
    end

    context "as a non-admin (attorney)" do
      it "returns 403 forbidden" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "Hacked Name" } }.to_json,
              headers: authenticated_headers(attorney_user)

        expect(response).to have_http_status(:forbidden)
        expect(tenant.reload.name).to eq("Acme Law Firm")
      end
    end

    context "as a viewer" do
      it "returns 403 forbidden" do
        patch "/api/v1/tenant",
              params: { tenant: { name: "Hacked Name" } }.to_json,
              headers: authenticated_headers(viewer_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 401 without authentication" do
      patch "/api/v1/tenant",
            params: { tenant: { name: "No Auth" } }.to_json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
