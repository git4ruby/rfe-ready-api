require "rails_helper"

RSpec.describe "Api::V1::Backups", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/backups" do
    it "returns backups for admin" do
      create(:backup, :completed, tenant: tenant, user: admin)

      get "/api/v1/backups", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
    end

    it "denies non-admin users" do
      get "/api/v1/backups", headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/backups" do
    it "creates a backup and enqueues job" do
      expect {
        post "/api/v1/backups", headers: authenticated_headers(admin)
      }.to change(Backup, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "denies non-admin" do
      post "/api/v1/backups", headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/backups/:id" do
    let!(:backup) { create(:backup, tenant: tenant, user: admin) }

    it "deletes backup as admin" do
      expect {
        delete "/api/v1/backups/#{backup.id}", headers: authenticated_headers(admin)
      }.to change(Backup, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
