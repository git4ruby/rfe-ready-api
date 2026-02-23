require "rails_helper"

RSpec.describe "Api::V1::Cases", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/cases" do
    it "returns paginated cases" do
      create_list(:rfe_case, 3, tenant: tenant, created_by: admin)

      get "/api/v1/cases", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(3)
      expect(body["meta"]).to include("current_page", "total_pages", "total_count")
    end

    it "scopes to current tenant" do
      create(:rfe_case, tenant: tenant, created_by: admin)
      other_tenant = create(:tenant)
      other_user = create(:user, tenant: other_tenant)
      ActsAsTenant.with_tenant(other_tenant) do
        create(:rfe_case, tenant: other_tenant, created_by: other_user)
      end

      get "/api/v1/cases", headers: authenticated_headers(admin)

      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(1)
    end

    it "returns 401 without authentication" do
      get "/api/v1/cases"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/cases/:id" do
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

    it "returns case detail" do
      get "/api/v1/cases/#{rfe_case.id}", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["id"]).to eq(rfe_case.id)
      expect(body["data"]["case_number"]).to eq(rfe_case.case_number)
    end

    it "returns 404 for non-existent case" do
      get "/api/v1/cases/00000000-0000-0000-0000-000000000000", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/cases" do
    let(:valid_params) do
      {
        rfe_case: {
          case_number: "RFE-2024-TEST",
          visa_type: "H-1B",
          petitioner_name: "Acme Corp",
          beneficiary_name: "John Smith"
        }
      }
    end

    it "creates a case as admin" do
      post "/api/v1/cases", params: valid_params.to_json, headers: authenticated_headers(admin)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["case_number"]).to eq("RFE-2024-TEST")
    end

    it "creates a case as attorney" do
      post "/api/v1/cases", params: valid_params.to_json, headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:created)
    end

    it "creates a case as paralegal" do
      post "/api/v1/cases", params: valid_params.to_json, headers: authenticated_headers(paralegal)

      expect(response).to have_http_status(:created)
    end

    it "denies viewer from creating a case" do
      post "/api/v1/cases", params: valid_params.to_json, headers: authenticated_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 422 for invalid params" do
      post "/api/v1/cases", params: { rfe_case: { case_number: "" } }.to_json,
           headers: authenticated_headers(admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/cases/:id" do
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

    it "updates a case" do
      patch "/api/v1/cases/#{rfe_case.id}",
            params: { rfe_case: { notes: "Updated notes" } }.to_json,
            headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(rfe_case.reload.notes).to eq("Updated notes")
    end

    it "denies viewer from updating" do
      patch "/api/v1/cases/#{rfe_case.id}",
            params: { rfe_case: { notes: "Hacked" } }.to_json,
            headers: authenticated_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/cases/:id" do
    let!(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

    it "deletes as admin" do
      expect {
        delete "/api/v1/cases/#{rfe_case.id}", headers: authenticated_headers(admin)
      }.to change(RfeCase, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "denies attorney from deleting" do
      delete "/api/v1/cases/#{rfe_case.id}", headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end

    it "denies paralegal from deleting" do
      delete "/api/v1/cases/#{rfe_case.id}", headers: authenticated_headers(paralegal)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/cases/:id/start_analysis" do
    let(:rfe_case) { create(:rfe_case, :draft, tenant: tenant, created_by: admin) }

    before do
      create(:rfe_document, :rfe_notice, tenant: tenant, case: rfe_case, uploaded_by: admin)
    end

    it "transitions to analyzing and enqueues job" do
      post "/api/v1/cases/#{rfe_case.id}/start_analysis", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(rfe_case.reload.status).to eq("analyzing")
    end

    it "requires at least one RFE notice document" do
      rfe_case.rfe_documents.destroy_all

      post "/api/v1/cases/#{rfe_case.id}/start_analysis", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "denies viewer" do
      post "/api/v1/cases/#{rfe_case.id}/start_analysis", headers: authenticated_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/cases/:id/assign_attorney" do
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

    it "assigns attorney as admin" do
      patch "/api/v1/cases/#{rfe_case.id}/assign_attorney",
            params: { attorney_id: attorney.id }.to_json,
            headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(rfe_case.reload.assigned_attorney).to eq(attorney)
    end

    it "denies paralegal from assigning" do
      patch "/api/v1/cases/#{rfe_case.id}/assign_attorney",
            params: { attorney_id: attorney.id }.to_json,
            headers: authenticated_headers(paralegal)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/cases/:id/archive" do
    let(:rfe_case) { create(:rfe_case, :draft, tenant: tenant, created_by: admin) }

    it "archives as admin" do
      post "/api/v1/cases/#{rfe_case.id}/archive", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(rfe_case.reload.status).to eq("archived")
    end

    it "denies viewer" do
      post "/api/v1/cases/#{rfe_case.id}/archive", headers: authenticated_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/cases/:id/reopen" do
    let(:rfe_case) { create(:rfe_case, :archived, tenant: tenant, created_by: admin) }

    it "reopens as admin" do
      post "/api/v1/cases/#{rfe_case.id}/reopen", headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(rfe_case.reload.status).to eq("draft")
    end

    it "denies attorney from reopening" do
      post "/api/v1/cases/#{rfe_case.id}/reopen", headers: authenticated_headers(attorney)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/cases/bulk_update_status" do
    let!(:case1) { create(:rfe_case, :draft, tenant: tenant, created_by: admin) }
    let!(:case2) { create(:rfe_case, :draft, tenant: tenant, created_by: admin) }

    it "bulk archives cases" do
      post "/api/v1/cases/bulk_update_status",
           params: { ids: [case1.id, case2.id], action_name: "archive" }.to_json,
           headers: authenticated_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["success"]).to eq(2)
    end

    it "rejects invalid action" do
      post "/api/v1/cases/bulk_update_status",
           params: { ids: [case1.id], action_name: "archive" }.to_json,
           headers: authenticated_headers(viewer)

      # Viewer can't archive, so all should fail
      body = JSON.parse(response.body)
      expect(body["data"]["success"]).to eq(0)
      expect(body["data"]["failed"]).to eq(1)
    end
  end
end
