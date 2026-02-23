require "rails_helper"

RSpec.describe "Api::V1::Sessions", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant, password: "Password123!") }

  describe "POST /api/v1/users/sign_in" do
    it "returns JWT token and user data on success" do
      post "/api/v1/users/sign_in", params: {
        user: { email: user.email, password: "Password123!" }
      }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Authorization"]).to be_present
      body = JSON.parse(response.body)
      expect(body["data"]["attributes"]["email"]).to eq(user.email)
      expect(body["data"]["attributes"]["role"]).to eq(user.role)
      expect(body["data"]["attributes"]["tenant_id"]).to eq(user.tenant_id)
    end

    it "returns 401 for invalid credentials" do
      post "/api/v1/users/sign_in", params: {
        user: { email: user.email, password: "wrong" }
      }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["error"]).to be_present
    end

    it "returns 401 for non-existent user" do
      post "/api/v1/users/sign_in", params: {
        user: { email: "nobody@example.com", password: "Password123!" }
      }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "includes 2FA flag when otp is required" do
      user.update!(otp_required_for_login: true, otp_secret: ROTP::Base32.random)

      post "/api/v1/users/sign_in", params: {
        user: { email: user.email, password: "Password123!" }
      }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["attributes"]["otp_required_for_login"]).to be true
    end
  end

  describe "DELETE /api/v1/users/sign_out" do
    it "logs out successfully" do
      headers = authenticated_headers(user)
      delete "/api/v1/users/sign_out", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["meta"]["message"]).to match(/logged out/i)
    end

    it "returns 401 without auth token" do
      delete "/api/v1/users/sign_out", headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
