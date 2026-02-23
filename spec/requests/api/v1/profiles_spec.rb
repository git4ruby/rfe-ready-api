require "rails_helper"

RSpec.describe "Api::V1::Profiles", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant, password: "Password123!") }

  describe "GET /api/v1/profile" do
    it "returns the current user profile" do
      get "/api/v1/profile", headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["email"]).to eq(user.email)
      expect(body["data"]["first_name"]).to eq(user.first_name)
    end

    it "returns 401 without auth" do
      get "/api/v1/profile"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/profile" do
    it "updates profile fields" do
      patch "/api/v1/profile",
            params: { profile: { first_name: "Updated" } }.to_json,
            headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      expect(user.reload.first_name).to eq("Updated")
    end

    it "merges preferences" do
      user.update!(preferences: { "timezone" => "UTC" })

      patch "/api/v1/profile",
            params: { profile: { preferences: { dashboard_layout: "compact" } } }.to_json,
            headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      prefs = user.reload.preferences
      expect(prefs["timezone"]).to eq("UTC")
      expect(prefs["dashboard_layout"]).to eq("compact")
    end
  end

  describe "PATCH /api/v1/profile/change_password" do
    it "changes password with correct current password" do
      patch "/api/v1/profile/change_password",
            params: {
              current_password: "Password123!",
              password: "NewPassword456!",
              password_confirmation: "NewPassword456!"
            }.to_json,
            headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?("NewPassword456!")).to be true
    end

    it "rejects wrong current password" do
      patch "/api/v1/profile/change_password",
            params: {
              current_password: "wrong",
              password: "NewPassword456!",
              password_confirmation: "NewPassword456!"
            }.to_json,
            headers: authenticated_headers(user)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects mismatched confirmation" do
      patch "/api/v1/profile/change_password",
            params: {
              current_password: "Password123!",
              password: "NewPassword456!",
              password_confirmation: "Different789!"
            }.to_json,
            headers: authenticated_headers(user)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
