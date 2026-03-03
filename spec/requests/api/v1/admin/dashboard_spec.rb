require "rails_helper"

RSpec.describe "Api::V1::Admin::Dashboard", type: :request do
  let(:platform_tenant) { create(:tenant, :platform) }
  let(:super_admin) { create(:user, :super_admin, tenant: platform_tenant) }

  describe "GET /api/v1/admin/dashboard" do
    context "as a super admin" do
      let!(:tenant_a) { create(:tenant, :professional, name: "Firm Alpha") }
      let!(:tenant_b) { create(:tenant, :trial, name: "Firm Beta") }
      let!(:tenant_c) { create(:tenant, :enterprise, name: "Firm Gamma", status: :suspended) }

      let!(:user_a) { create(:user, :admin, tenant: tenant_a) }
      let!(:user_b) { create(:user, :attorney, tenant: tenant_b) }

      it "returns 200 with dashboard stats" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        data = body["data"]

        expect(data).to have_key("total_tenants")
        expect(data).to have_key("tenants_by_status")
        expect(data).to have_key("tenants_by_plan")
        expect(data).to have_key("total_users")
        expect(data).to have_key("total_cases")
        expect(data).to have_key("cases_by_status")
        expect(data).to have_key("recent_tenants")
        expect(data).to have_key("growth")
      end

      it "counts only real tenants (excludes platform tenant)" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        body = JSON.parse(response.body)
        data = body["data"]

        # 3 real tenants created above; platform tenant should be excluded
        expect(data["total_tenants"]).to eq(3)
      end

      it "excludes super admin users from total_users count" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        body = JSON.parse(response.body)
        data = body["data"]

        # user_a and user_b are non-super-admin users
        expect(data["total_users"]).to eq(2)
      end

      it "groups tenants by status" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        body = JSON.parse(response.body)
        tenants_by_status = body["data"]["tenants_by_status"]

        expect(tenants_by_status["active"]).to eq(2)
        expect(tenants_by_status["suspended"]).to eq(1)
      end

      it "groups tenants by plan" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        body = JSON.parse(response.body)
        tenants_by_plan = body["data"]["tenants_by_plan"]

        expect(tenants_by_plan["professional"]).to eq(1)
        expect(tenants_by_plan["trial"]).to eq(1)
        expect(tenants_by_plan["enterprise"]).to eq(1)
      end

      it "returns recent tenants limited to 5" do
        create_list(:tenant, 4) # 4 more + 3 existing = 7 total real tenants

        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        body = JSON.parse(response.body)
        recent_tenants = body["data"]["recent_tenants"]

        expect(recent_tenants.length).to eq(5)
      end

      it "includes growth metrics for the current month" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(super_admin)

        body = JSON.parse(response.body)
        growth = body["data"]["growth"]

        expect(growth).to have_key("tenants_this_month")
        expect(growth).to have_key("users_this_month")
        expect(growth).to have_key("cases_this_month")

        # All tenants and users were created in this test run (current month)
        expect(growth["tenants_this_month"]).to eq(3)
        expect(growth["users_this_month"]).to eq(2)
      end
    end

    context "as a non-super-admin" do
      let(:tenant) { create(:tenant) }
      let(:regular_admin) { create(:user, :admin, tenant: tenant) }

      it "returns 403 forbidden" do
        get "/api/v1/admin/dashboard", headers: authenticated_headers(regular_admin)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/admin/dashboard"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
