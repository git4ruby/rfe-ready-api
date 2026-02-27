require "rails_helper"

RSpec.describe "Api::V1::SlackIntegrations", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:headers) { auth_headers(admin) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/slack_integrations" do
    it "returns list of integrations for admin" do
      create(:slack_integration, tenant: tenant)

      get "/api/v1/slack_integrations", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
    end

    it "returns 403 for non-admin" do
      get "/api/v1/slack_integrations", headers: auth_headers(attorney)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth" do
      get "/api/v1/slack_integrations"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/slack_integrations" do
    let(:valid_params) do
      {
        slack_integration: {
          webhook_url: "https://hooks.slack.com/services/T00/B00/new",
          channel_name: "#alerts",
          events: ["case.created", "case.status_changed"],
          active: true
        }
      }
    end

    it "creates an integration" do
      post "/api/v1/slack_integrations", params: valid_params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["webhook_url"]).to eq("https://hooks.slack.com/services/T00/B00/new")
      expect(body["data"]["events"]).to eq(["case.created", "case.status_changed"])
    end

    it "returns 403 for non-admin" do
      post "/api/v1/slack_integrations", params: valid_params, headers: auth_headers(attorney), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/slack_integrations/:id" do
    let!(:integration) { create(:slack_integration, tenant: tenant) }

    it "updates the integration" do
      patch "/api/v1/slack_integrations/#{integration.id}",
        params: { slack_integration: { channel_name: "#updated" } },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["channel_name"]).to eq("#updated")
    end

    it "returns 403 for non-admin" do
      patch "/api/v1/slack_integrations/#{integration.id}",
        params: { slack_integration: { active: false } },
        headers: auth_headers(attorney),
        as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/slack_integrations/:id" do
    let!(:integration) { create(:slack_integration, tenant: tenant) }

    it "destroys the integration" do
      expect {
        delete "/api/v1/slack_integrations/#{integration.id}", headers: headers
      }.to change(SlackIntegration, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 403 for non-admin" do
      delete "/api/v1/slack_integrations/#{integration.id}", headers: auth_headers(attorney)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/slack_integrations/:id/test_notification" do
    let!(:integration) { create(:slack_integration, tenant: tenant) }

    it "queues a test notification" do
      post "/api/v1/slack_integrations/#{integration.id}/test_notification", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["message"]).to eq("Test notification queued.")
    end

    it "returns 403 for non-admin" do
      post "/api/v1/slack_integrations/#{integration.id}/test_notification", headers: auth_headers(attorney)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
