require "rails_helper"

RSpec.describe "Api::V1::Admin::Tenants", type: :request do
  let(:platform_tenant) { create(:tenant, :platform) }
  let(:super_admin) { create(:user, :super_admin, tenant: platform_tenant) }

  before { super_admin } # eagerly create to avoid count mismatches

  describe "GET /api/v1/admin/tenants" do
    let!(:active_professional) { create(:tenant, :professional, name: "Pro Firm", status: :active) }
    let!(:active_trial) { create(:tenant, :trial, name: "Trial Firm", status: :active) }
    let!(:suspended_tenant) { create(:tenant, :basic, name: "Suspended Firm", status: :suspended) }

    it "returns 200 with a paginated list of real tenants" do
      get "/api/v1/admin/tenants", headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["meta"]).to include("current_page", "total_pages", "total_count", "per_page")
      # Should only include real tenants (not platform)
      tenant_names = body["data"].map { |t| t["name"] }
      expect(tenant_names).not_to include("Platform Admin")
    end

    it "filters by status" do
      get "/api/v1/admin/tenants",
          params: { status: "suspended" },
          headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(1)
      expect(body["data"].first["name"]).to eq("Suspended Firm")
    end

    it "filters by plan" do
      get "/api/v1/admin/tenants",
          params: { plan: "professional" },
          headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(1)
      expect(body["data"].first["name"]).to eq("Pro Firm")
    end

    it "filters by search term (name ILIKE)" do
      get "/api/v1/admin/tenants",
          params: { search: "Pro" },
          headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(1)
      expect(body["data"].first["name"]).to eq("Pro Firm")
    end

    it "returns an empty list when no tenants match the filter" do
      get "/api/v1/admin/tenants",
          params: { search: "Nonexistent" },
          headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_empty
    end
  end

  describe "GET /api/v1/admin/tenants/:id" do
    let!(:tenant) { create(:tenant, :professional, name: "Show Firm") }

    it "returns 200 with the tenant details" do
      get "/api/v1/admin/tenants/#{tenant.id}", headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["name"]).to eq("Show Firm")
    end

    it "returns 404 for a non-existent tenant" do
      get "/api/v1/admin/tenants/999999", headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Resource not found.")
    end
  end

  describe "POST /api/v1/admin/tenants" do
    let(:valid_params) do
      {
        tenant: {
          name: "New Law Firm",
          plan: "professional",
          status: "active",
          data_retention_days: 365
        }
      }
    end

    it "creates a new tenant and returns 201" do
      expect {
        post "/api/v1/admin/tenants",
             params: valid_params.to_json,
             headers: authenticated_headers(super_admin)
      }.to change(Tenant, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["name"]).to eq("New Law Firm")
    end

    it "returns 422 with invalid params (missing name)" do
      post "/api/v1/admin/tenants",
           params: { tenant: { name: "", plan: "trial" } }.to_json,
           headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Validation failed.")
      expect(body["details"]).to be_present
    end
  end

  describe "PATCH /api/v1/admin/tenants/:id" do
    let!(:tenant) { create(:tenant, name: "Old Name") }

    it "updates the tenant and returns 200" do
      patch "/api/v1/admin/tenants/#{tenant.id}",
            params: { tenant: { name: "New Name" } }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["name"]).to eq("New Name")
      expect(tenant.reload.name).to eq("New Name")
    end
  end

  describe "DELETE /api/v1/admin/tenants/:id" do
    context "with a regular tenant" do
      let!(:tenant) { create(:tenant, name: "Deletable Firm") }

      it "deletes the tenant and returns success" do
        expect {
          delete "/api/v1/admin/tenants/#{tenant.id}",
                 headers: authenticated_headers(super_admin)
        }.to change(Tenant, :count).by(-1)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["meta"]["message"]).to eq("Tenant deleted successfully.")
      end
    end

    context "with the platform tenant" do
      it "returns 404 (platform tenant excluded from real_tenants scope)" do
        expect {
          delete "/api/v1/admin/tenants/#{platform_tenant.id}",
                 headers: authenticated_headers(super_admin)
        }.not_to change(Tenant, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/admin/tenants/:id/change_status" do
    let!(:tenant) { create(:tenant, status: :active) }

    it "changes the tenant status and returns 200" do
      patch "/api/v1/admin/tenants/#{tenant.id}/change_status",
            params: { status: "suspended" }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["meta"]["message"]).to eq("Tenant status changed to suspended.")
      expect(tenant.reload.status).to eq("suspended")
    end

    it "returns 422 for an invalid status" do
      patch "/api/v1/admin/tenants/#{tenant.id}/change_status",
            params: { status: "bogus_status" }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to include("Invalid status")
    end
  end

  describe "PATCH /api/v1/admin/tenants/:id/change_plan" do
    let!(:tenant) { create(:tenant, :trial) }

    it "changes the tenant plan and returns 200" do
      patch "/api/v1/admin/tenants/#{tenant.id}/change_plan",
            params: { plan: "enterprise" }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["meta"]["message"]).to eq("Tenant plan changed to enterprise.")
      expect(tenant.reload.plan).to eq("enterprise")
    end

    it "returns 422 for an invalid plan" do
      patch "/api/v1/admin/tenants/#{tenant.id}/change_plan",
            params: { plan: "bogus_plan" }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to include("Invalid plan")
    end
  end

  describe "authorization" do
    let(:tenant) { create(:tenant) }
    let(:regular_admin) { create(:user, :admin, tenant: tenant) }

    it "returns 403 for a non-super-admin on index" do
      get "/api/v1/admin/tenants", headers: authenticated_headers(regular_admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-super-admin on create" do
      post "/api/v1/admin/tenants",
           params: { tenant: { name: "Unauthorized" } }.to_json,
           headers: authenticated_headers(regular_admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without authentication" do
      get "/api/v1/admin/tenants"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
