require "rails_helper"

RSpec.describe "Api::V1::Webhooks", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:headers) { auth_headers(admin) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/webhooks" do
    it "returns list of webhooks for admin" do
      create(:webhook, tenant: tenant, secret: "top_secret")
      create(:webhook, tenant: tenant, url: "https://other.com/hook")

      get "/api/v1/webhooks", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(2)
    end

    it "does not expose secret in responses" do
      create(:webhook, tenant: tenant, secret: "top_secret")

      get "/api/v1/webhooks", headers: headers

      body = JSON.parse(response.body)
      body["data"].each do |webhook_data|
        expect(webhook_data).not_to have_key("secret")
      end
    end

    it "returns 403 for non-admin" do
      get "/api/v1/webhooks", headers: auth_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth" do
      get "/api/v1/webhooks"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/webhooks/:id" do
    let!(:webhook) { create(:webhook, tenant: tenant, secret: "hidden_secret") }

    it "returns the webhook for admin" do
      get "/api/v1/webhooks/#{webhook.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["id"]).to eq(webhook.id)
    end

    it "does not expose secret" do
      get "/api/v1/webhooks/#{webhook.id}", headers: headers

      body = JSON.parse(response.body)
      expect(body["data"]).not_to have_key("secret")
    end
  end

  describe "POST /api/v1/webhooks" do
    let(:valid_params) do
      {
        webhook: {
          url: "https://myapp.com/webhook",
          events: ["case.created", "document.uploaded"],
          secret: "my_secret",
          description: "My webhook"
        }
      }
    end

    it "creates a webhook" do
      expect {
        post "/api/v1/webhooks", params: valid_params, headers: headers, as: :json
      }.to change(Webhook, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["url"]).to eq("https://myapp.com/webhook")
      expect(body["data"]["events"]).to eq(["case.created", "document.uploaded"])
    end

    it "does not expose secret in create response" do
      post "/api/v1/webhooks", params: valid_params, headers: headers, as: :json

      body = JSON.parse(response.body)
      expect(body["data"]).not_to have_key("secret")
    end

    it "returns 422 with invalid params" do
      post "/api/v1/webhooks", params: { webhook: { url: "", events: [] } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 403 for non-admin" do
      post "/api/v1/webhooks", params: valid_params, headers: auth_headers(attorney), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/webhooks/:id" do
    let!(:webhook) { create(:webhook, tenant: tenant) }

    it "updates the webhook" do
      patch "/api/v1/webhooks/#{webhook.id}",
        params: { webhook: { description: "Updated description", active: false } },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["description"]).to eq("Updated description")
      expect(body["data"]["active"]).to eq(false)
    end

    it "does not expose secret in update response" do
      patch "/api/v1/webhooks/#{webhook.id}",
        params: { webhook: { description: "New desc" } },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["data"]).not_to have_key("secret")
    end

    it "returns 403 for non-admin" do
      patch "/api/v1/webhooks/#{webhook.id}",
        params: { webhook: { active: false } },
        headers: auth_headers(attorney),
        as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/webhooks/:id" do
    let!(:webhook) { create(:webhook, tenant: tenant) }

    it "destroys the webhook" do
      expect {
        delete "/api/v1/webhooks/#{webhook.id}", headers: headers
      }.to change(Webhook, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 403 for non-admin" do
      delete "/api/v1/webhooks/#{webhook.id}", headers: auth_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/webhooks/:id/test_delivery" do
    let!(:webhook) { create(:webhook, tenant: tenant, events: ["case.created"]) }

    it "queues a test webhook delivery" do
      post "/api/v1/webhooks/#{webhook.id}/test_delivery", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["message"]).to eq("Test webhook queued for delivery.")
    end

    it "returns 403 for non-admin" do
      post "/api/v1/webhooks/#{webhook.id}/test_delivery", headers: auth_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
