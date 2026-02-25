require "rails_helper"

RSpec.describe "Api::V1::TwoFactor", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant, password: "Password123!") }

  before { ActsAsTenant.current_tenant = tenant }

  describe "POST /api/v1/two_factor/setup" do
    it "returns 200 with secret, provisioning_uri, and qr_svg" do
      post "/api/v1/two_factor/setup", headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["secret"]).to be_present
      expect(body["data"]["provisioning_uri"]).to be_present
      expect(body["data"]["qr_svg"]).to be_present
    end

    it "returns 401 when unauthenticated" do
      post "/api/v1/two_factor/setup", headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/two_factor/verify" do
    context "with a valid TOTP code" do
      it "returns 200, enables 2FA, and returns backup codes" do
        # First set up the secret
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret)

        # Generate a valid TOTP code
        totp = ROTP::TOTP.new(secret, issuer: "RFE Ready")
        valid_code = totp.now

        post "/api/v1/two_factor/verify",
             params: { code: valid_code }.to_json,
             headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["enabled"]).to be true
        expect(body["data"]["backup_codes"]).to be_an(Array)
        expect(body["data"]["backup_codes"].length).to eq(8)

        # Verify user record was updated
        user.reload
        expect(user.otp_required_for_login).to be true
      end
    end

    context "with an invalid TOTP code" do
      it "returns 422" do
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret)

        post "/api/v1/two_factor/verify",
             params: { code: "000000" }.to_json,
             headers: authenticated_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to match(/invalid verification code/i)
      end
    end
  end

  describe "POST /api/v1/two_factor/validate" do
    context "with a valid TOTP code" do
      it "returns 200" do
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret, otp_required_for_login: true)

        totp = ROTP::TOTP.new(secret, issuer: "RFE Ready")
        valid_code = totp.now

        post "/api/v1/two_factor/validate",
             params: { code: valid_code }.to_json,
             headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["valid"]).to be true
      end
    end

    context "with a valid backup code" do
      it "returns 200 and consumes the backup code" do
        secret = ROTP::Base32.random
        backup_codes = Array.new(8) { SecureRandom.hex(4).upcase }
        user.update!(
          otp_secret: secret,
          otp_required_for_login: true,
          otp_backup_codes: backup_codes
        )

        post "/api/v1/two_factor/validate",
             params: { code: backup_codes.first }.to_json,
             headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["valid"]).to be true
        expect(body["data"]["backup_code_used"]).to be true
        expect(body["data"]["remaining_backup_codes"]).to eq(7)

        # Verify the backup code was consumed
        user.reload
        expect(user.otp_backup_codes).not_to include(backup_codes.first)
        expect(user.otp_backup_codes.length).to eq(7)
      end
    end

    context "with an invalid code" do
      it "returns 422" do
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret, otp_required_for_login: true)

        post "/api/v1/two_factor/validate",
             params: { code: "000000" }.to_json,
             headers: authenticated_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to match(/invalid code/i)
      end
    end

    context "when 2FA is not enabled" do
      it "returns 422" do
        user.update!(otp_secret: nil, otp_required_for_login: false)

        post "/api/v1/two_factor/validate",
             params: { code: "123456" }.to_json,
             headers: authenticated_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to match(/not enabled/i)
      end
    end
  end

  describe "DELETE /api/v1/two_factor" do
    context "with valid password and TOTP code" do
      it "returns 200 and disables 2FA" do
        secret = ROTP::Base32.random
        user.update!(
          otp_secret: secret,
          otp_required_for_login: true,
          otp_backup_codes: ["ABCD1234"]
        )

        totp = ROTP::TOTP.new(secret, issuer: "RFE Ready")
        valid_code = totp.now

        delete "/api/v1/two_factor",
               params: { password: "Password123!", code: valid_code }.to_json,
               headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["enabled"]).to be false

        # Verify user record was updated
        user.reload
        expect(user.otp_required_for_login).to be false
        expect(user.otp_secret).to be_nil
        expect(user.otp_backup_codes).to be_empty
      end
    end

    context "with wrong password" do
      it "returns 422" do
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret, otp_required_for_login: true)

        totp = ROTP::TOTP.new(secret, issuer: "RFE Ready")
        valid_code = totp.now

        delete "/api/v1/two_factor",
               params: { password: "WrongPassword!", code: valid_code }.to_json,
               headers: authenticated_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to match(/password is incorrect/i)
      end
    end

    it "returns 401 when unauthenticated" do
      delete "/api/v1/two_factor", headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
