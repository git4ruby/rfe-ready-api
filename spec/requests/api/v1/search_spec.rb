require "rails_helper"

RSpec.describe "Api::V1::Search", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/search" do
    before do
      create(:rfe_case, tenant: tenant, created_by: user, petitioner_name: "Acme Corporation")
      create(:knowledge_doc, tenant: tenant, uploaded_by: user, title: "H-1B Specialty Guide")
    end

    it "returns matching results" do
      get "/api/v1/search?q=acme", headers: authenticated_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["cases"].length).to eq(1)
    end

    it "returns empty results for short query" do
      get "/api/v1/search?q=a", headers: authenticated_headers(user)

      body = JSON.parse(response.body)
      expect(body["data"]["cases"]).to be_empty
    end

    it "searches knowledge docs" do
      get "/api/v1/search?q=specialty", headers: authenticated_headers(user)

      body = JSON.parse(response.body)
      expect(body["data"]["knowledge_docs"].length).to eq(1)
    end
  end
end
