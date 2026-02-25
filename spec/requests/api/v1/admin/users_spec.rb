require "rails_helper"

RSpec.describe "Api::V1::Admin::Users", type: :request do
  let(:platform_tenant) { create(:tenant, :platform) }
  let(:super_admin) { create(:user, :super_admin, tenant: platform_tenant) }
  let(:target_tenant) { create(:tenant, :professional, name: "Target Firm") }

  before { super_admin; target_tenant } # eagerly create to avoid count mismatches

  describe "GET /api/v1/admin/tenants/:tenant_id/users" do
    before do
      create(:user, :admin, tenant: target_tenant, first_name: "Alice", last_name: "Adams")
      create(:user, :attorney, tenant: target_tenant, first_name: "Bob", last_name: "Baker")
      create(:user, :viewer, tenant: target_tenant, first_name: "Carol", last_name: "Clark")
    end

    it "returns 200 with a paginated list of users for the tenant" do
      get "/api/v1/admin/tenants/#{target_tenant.id}/users",
          headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["data"].length).to eq(3)
      expect(body["meta"]).to include("current_page", "total_pages", "total_count", "per_page")
    end

    it "returns users ordered by last_name, first_name" do
      get "/api/v1/admin/tenants/#{target_tenant.id}/users",
          headers: authenticated_headers(super_admin)

      body = JSON.parse(response.body)
      last_names = body["data"].map { |u| u["last_name"] }
      expect(last_names).to eq(%w[Adams Baker Clark])
    end

    it "does not include users from other tenants" do
      other_tenant = create(:tenant, name: "Other Firm")
      create(:user, :admin, tenant: other_tenant, first_name: "Dave", last_name: "Delta")

      get "/api/v1/admin/tenants/#{target_tenant.id}/users",
          headers: authenticated_headers(super_admin)

      body = JSON.parse(response.body)
      emails = body["data"].map { |u| u["email"] }
      target_user_emails = User.where(tenant: target_tenant).pluck(:email)
      expect(emails).to match_array(target_user_emails)
    end

    it "returns 404 for a non-existent tenant" do
      get "/api/v1/admin/tenants/999999/users",
          headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Resource not found.")
    end
  end

  describe "POST /api/v1/admin/tenants/:tenant_id/users" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          first_name: "Jane",
          last_name: "Doe",
          role: "attorney",
          bar_number: "1234567"
        }
      }
    end

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it "creates a user in the specified tenant and returns 201" do
      expect {
        post "/api/v1/admin/tenants/#{target_tenant.id}/users",
             params: valid_params.to_json,
             headers: authenticated_headers(super_admin)
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["email"]).to eq("newuser@example.com")
      expect(body["data"]["first_name"]).to eq("Jane")
      expect(body["meta"]["message"]).to include("Target Firm")

      created_user = User.find_by(email: "newuser@example.com")
      expect(created_user.tenant).to eq(target_tenant)
      expect(created_user.confirmed_at).to be_present
    end

    it "enqueues a welcome email" do
      expect {
        post "/api/v1/admin/tenants/#{target_tenant.id}/users",
             params: valid_params.to_json,
             headers: authenticated_headers(super_admin)
      }.to have_enqueued_job.on_queue("default")
    end

    it "returns 422 with invalid params (missing email)" do
      invalid_params = {
        user: {
          email: "",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          first_name: "Jane",
          last_name: "Doe",
          role: "admin"
        }
      }

      post "/api/v1/admin/tenants/#{target_tenant.id}/users",
           params: invalid_params.to_json,
           headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Validation failed.")
      expect(body["details"]).to be_present
    end

    it "returns 422 with mismatched password confirmation" do
      bad_params = valid_params.deep_merge(user: { password_confirmation: "Different123!" })

      post "/api/v1/admin/tenants/#{target_tenant.id}/users",
           params: bad_params.to_json,
           headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when attorney is missing bar_number" do
      no_bar_params = valid_params.deep_merge(user: { bar_number: nil })

      post "/api/v1/admin/tenants/#{target_tenant.id}/users",
           params: no_bar_params.to_json,
           headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for a non-existent tenant" do
      post "/api/v1/admin/tenants/999999/users",
           params: valid_params.to_json,
           headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "authorization" do
    let(:regular_tenant) { create(:tenant) }
    let(:regular_admin) { create(:user, :admin, tenant: regular_tenant) }

    it "returns 403 for a non-super-admin on index" do
      get "/api/v1/admin/tenants/#{target_tenant.id}/users",
          headers: authenticated_headers(regular_admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-super-admin on create" do
      post "/api/v1/admin/tenants/#{target_tenant.id}/users",
           params: { user: { email: "test@example.com", first_name: "X", last_name: "Y", role: "viewer", password: "Pass123!", password_confirmation: "Pass123!" } }.to_json,
           headers: authenticated_headers(regular_admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without authentication" do
      get "/api/v1/admin/tenants/#{target_tenant.id}/users"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
