require "rails_helper"

RSpec.describe "Api::V1::FeatureFlags", type: :request do
  let(:tenant) { create(:tenant, :professional) }
  let(:admin_user) { create(:user, :admin, tenant: tenant) }
  let(:viewer_user) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/feature_flags" do
    context "with a fully enabled flag (no restrictions)" do
      before do
        create(:feature_flag, tenant: tenant, name: "ai_analysis", enabled: true, allowed_roles: [], allowed_plans: [])
      end

      it "returns true for any authenticated user" do
        get "/api/v1/feature_flags", headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["ai_analysis"]).to be true
      end

      it "returns true for a viewer as well" do
        get "/api/v1/feature_flags", headers: authenticated_headers(viewer_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["ai_analysis"]).to be true
      end
    end

    context "with a role-restricted flag" do
      before do
        create(:feature_flag, tenant: tenant, name: "bulk_actions", enabled: true, allowed_roles: %w[admin], allowed_plans: [])
      end

      it "returns true for an admin" do
        get "/api/v1/feature_flags", headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["bulk_actions"]).to be true
      end

      it "returns false for a viewer" do
        get "/api/v1/feature_flags", headers: authenticated_headers(viewer_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["bulk_actions"]).to be false
      end
    end

    context "with a plan-restricted flag" do
      before do
        create(:feature_flag, tenant: tenant, name: "audit_log_export", enabled: true, allowed_roles: [], allowed_plans: %w[professional enterprise])
      end

      it "returns true when tenant plan matches" do
        get "/api/v1/feature_flags", headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["audit_log_export"]).to be true
      end

      it "returns false when tenant plan does not match" do
        trial_tenant = create(:tenant, :trial)
        trial_user = create(:user, :admin, tenant: trial_tenant)
        ActsAsTenant.current_tenant = trial_tenant

        create(:feature_flag, tenant: trial_tenant, name: "audit_log_export", enabled: true, allowed_roles: [], allowed_plans: %w[professional enterprise])

        get "/api/v1/feature_flags", headers: authenticated_headers(trial_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["audit_log_export"]).to be false
      end
    end

    context "with a disabled flag" do
      before do
        create(:feature_flag, :disabled, tenant: tenant, name: "disabled_feature", allowed_roles: [], allowed_plans: [])
      end

      it "returns false for any user" do
        get "/api/v1/feature_flags", headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["disabled_feature"]).to be false
      end
    end

    context "with multiple flags" do
      before do
        create(:feature_flag, tenant: tenant, name: "ai_analysis", enabled: true, allowed_roles: [], allowed_plans: [])
        create(:feature_flag, tenant: tenant, name: "bulk_actions", enabled: true, allowed_roles: %w[admin], allowed_plans: [])
        create(:feature_flag, :disabled, tenant: tenant, name: "beta_feature", allowed_roles: [], allowed_plans: [])
      end

      it "returns a hash with all flags and their computed values" do
        get "/api/v1/feature_flags", headers: authenticated_headers(admin_user)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]).to include(
          "ai_analysis" => true,
          "bulk_actions" => true,
          "beta_feature" => false
        )
      end
    end

    it "returns 401 without authentication" do
      get "/api/v1/feature_flags"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
