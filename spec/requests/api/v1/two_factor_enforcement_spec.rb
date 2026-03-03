require "rails_helper"

RSpec.describe "Api::V1::TwoFactorEnforcement", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "when tenant requires 2FA" do
    before { tenant.update!(two_factor_required: true) }

    context "and user has 2FA enabled" do
      before do
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret, otp_required_for_login: true)
      end

      it "allows access to protected endpoints" do
        get "/api/v1/dashboard", headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context "and user does NOT have 2FA enabled" do
      before { user.update!(otp_required_for_login: false) }

      it "returns 403 with 2fa_required code" do
        get "/api/v1/dashboard", headers: authenticated_headers(user)

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Two-factor authentication is required by your organization. Please set up 2FA.")
        expect(body["code"]).to eq("2fa_required")
      end
    end

    context "but 2FA setup endpoints remain accessible" do
      before { user.update!(otp_required_for_login: false) }

      it "allows access to POST /api/v1/two_factor/setup" do
        post "/api/v1/two_factor/setup", headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["secret"]).to be_present
      end
    end
  end

  describe "when tenant does NOT require 2FA" do
    before { tenant.update!(two_factor_required: false) }

    context "and user has 2FA enabled" do
      before do
        secret = ROTP::Base32.random
        user.update!(otp_secret: secret, otp_required_for_login: true)
      end

      it "allows access to protected endpoints" do
        get "/api/v1/dashboard", headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context "and user does NOT have 2FA enabled" do
      before { user.update!(otp_required_for_login: false) }

      it "allows access to protected endpoints" do
        get "/api/v1/dashboard", headers: authenticated_headers(user)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "super admin can toggle two_factor_required on a tenant" do
    let(:platform_tenant) { create(:tenant, :platform) }
    let(:super_admin) { create(:user, :super_admin, tenant: platform_tenant) }
    let(:target_tenant) { create(:tenant, two_factor_required: false) }

    it "enables two_factor_required via PATCH" do
      patch "/api/v1/admin/tenants/#{target_tenant.id}",
            params: { tenant: { two_factor_required: true } }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      expect(target_tenant.reload.two_factor_required).to be true
    end

    it "disables two_factor_required via PATCH" do
      target_tenant.update!(two_factor_required: true)

      patch "/api/v1/admin/tenants/#{target_tenant.id}",
            params: { tenant: { two_factor_required: false } }.to_json,
            headers: authenticated_headers(super_admin)

      expect(response).to have_http_status(:ok)
      expect(target_tenant.reload.two_factor_required).to be false
    end
  end
end
