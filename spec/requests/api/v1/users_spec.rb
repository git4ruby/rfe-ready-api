require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/users" do
    it "returns users list for admin" do
      get "/api/v1/users", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["meta"]).to include("total_count")
    end

    it "scopes users to the same tenant" do
      other_tenant = create(:tenant)
      create(:user, tenant: other_tenant)

      get "/api/v1/users", headers: authenticated_headers(admin)

      body = JSON.parse(response.body)
      tenant_ids = body["data"].map { |u| u["id"] }
      expect(User.where(id: tenant_ids).pluck(:tenant_id).uniq).to eq([ tenant.id ])
    end
  end

  describe "POST /api/v1/users" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          first_name: "New",
          last_name: "User",
          role: "paralegal"
        }
      }
    end

    it "creates a user as admin" do
      # Ensure admin is created before measuring count change
      admin

      expect {
        post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(admin)
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "denies non-admin from creating users" do
      post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/users/:id" do
    it "updates user role as admin" do
      patch "/api/v1/users/#{attorney.id}",
            params: { user: { role: "paralegal" } }.to_json,
            headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(attorney.reload.role).to eq("paralegal")
    end

    it "cannot update self" do
      patch "/api/v1/users/#{admin.id}",
            params: { user: { role: "viewer" } }.to_json,
            headers: authenticated_headers(admin)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
