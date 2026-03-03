require "rails_helper"

RSpec.describe "Api::V1::Omniauth", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:frontend_url) { ENV.fetch("FRONTEND_URL", "http://localhost:5173") }

  let(:omniauth_auth) do
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "123456",
      info: OmniAuth::AuthHash::InfoHash.new(
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name
      )
    )
  end

  describe "GET /api/v1/auth/:provider/callback" do
    context "when authentication succeeds with an existing active user" do
      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:google_oauth2] = omniauth_auth
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:google_oauth2] = nil
      end

      it "redirects to frontend with token and user data" do
        get "/api/v1/auth/google_oauth2/callback",
            env: { "omniauth.auth" => omniauth_auth }

        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers["Location"]
        expect(redirect_location).to start_with("#{frontend_url}/sso/callback?")
        expect(redirect_location).to include("email=#{CGI.escape(user.email)}")
        expect(redirect_location).to include("user_id=#{user.id}")
        expect(redirect_location).to include("first_name=")
        expect(redirect_location).to include("last_name=")
        expect(redirect_location).to include("role=")
        expect(redirect_location).to include("tenant_id=#{user.tenant_id}")
      end
    end

    context "when omniauth.auth is missing" do
      it "redirects to frontend with an error" do
        get "/api/v1/auth/google_oauth2/callback"

        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers["Location"]
        expect(redirect_location).to start_with("#{frontend_url}/sso/callback?")
        expect(redirect_location).to include("error=")
        expect(redirect_location).to include(CGI.escape("Authentication failed."))
      end
    end

    context "when user is not found" do
      it "redirects to frontend with no-account error" do
        unknown_auth = OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid: "999999",
          info: OmniAuth::AuthHash::InfoHash.new(
            email: "unknown@example.com",
            first_name: "Unknown",
            last_name: "User"
          )
        )

        get "/api/v1/auth/google_oauth2/callback",
            env: { "omniauth.auth" => unknown_auth }

        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers["Location"]
        expect(redirect_location).to include("error=")
        expect(redirect_location).to include(CGI.escape("No account found for unknown@example.com"))
      end
    end

    context "when user account is inactive" do
      let(:inactive_user) { create(:user, :inactive, tenant: tenant) }

      it "redirects to frontend with inactive error" do
        inactive_auth = OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid: "654321",
          info: OmniAuth::AuthHash::InfoHash.new(
            email: inactive_user.email,
            first_name: inactive_user.first_name,
            last_name: inactive_user.last_name
          )
        )

        get "/api/v1/auth/google_oauth2/callback",
            env: { "omniauth.auth" => inactive_auth }

        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers["Location"]
        expect(redirect_location).to include("error=")
        expect(redirect_location).to include(CGI.escape("Your account is inactive."))
      end
    end
  end

  describe "GET /api/v1/auth/failure" do
    it "redirects to frontend with error message from params" do
      get "/api/v1/auth/failure", params: { message: "invalid_credentials" }

      expect(response).to have_http_status(:redirect)
      redirect_location = response.headers["Location"]
      expect(redirect_location).to start_with("#{frontend_url}/sso/callback?")
      expect(redirect_location).to include("error=#{CGI.escape('invalid_credentials')}")
    end

    it "redirects with default error when no message param" do
      get "/api/v1/auth/failure"

      expect(response).to have_http_status(:redirect)
      redirect_location = response.headers["Location"]
      expect(redirect_location).to include("error=#{CGI.escape('Authentication failed.')}")
    end
  end
end
