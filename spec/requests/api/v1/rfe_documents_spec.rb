require "rails_helper"

RSpec.describe "Api::V1::RfeDocuments", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

  let(:base_url) { "/api/v1/cases/#{rfe_case.id}/rfe_documents" }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/cases/:case_id/rfe_documents" do
    let!(:document1) { create(:rfe_document, :rfe_notice, case: rfe_case, tenant: tenant, uploaded_by: admin) }
    let!(:document2) { create(:rfe_document, :supporting_evidence, case: rfe_case, tenant: tenant, uploaded_by: admin) }

    context "when authenticated as admin" do
      it "returns all documents for the case" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(2)
      end
    end

    context "when authenticated as viewer" do
      it "returns documents (show? is allowed for all roles)" do
        get base_url, headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(2)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get base_url

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "tenant scoping" do
      let(:other_tenant) { create(:tenant) }
      let(:other_user) { create(:user, :admin, tenant: other_tenant) }
      let(:other_case) { create(:rfe_case, tenant: other_tenant, created_by: other_user) }
      let!(:other_document) { create(:rfe_document, case: other_case, tenant: other_tenant, uploaded_by: other_user) }

      it "does not return documents from another tenant" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        ids = body["data"].map { |d| d["id"] }
        expect(ids).not_to include(other_document.id)
      end
    end
  end

  describe "GET /api/v1/cases/:case_id/rfe_documents/:id" do
    let!(:document) { create(:rfe_document, :rfe_notice, case: rfe_case, tenant: tenant, uploaded_by: admin) }

    context "when authenticated" do
      it "returns the document" do
        get "#{base_url}/#{document.id}", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["id"]).to eq(document.id)
      end
    end

    context "when document does not exist" do
      it "returns 404" do
        get "#{base_url}/999999", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "#{base_url}/#{document.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/cases/:case_id/rfe_documents" do
    context "when authenticated as admin" do
      it "creates a document with document_type param" do
        post base_url,
          params: { document_type: "rfe_notice", filename: "test_notice.pdf" }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["document_type"]).to eq("rfe_notice")
      end

      it "defaults document_type to supporting_evidence when not provided" do
        post base_url,
          params: { filename: "evidence.pdf" }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["document_type"]).to eq("supporting_evidence")
      end
    end

    context "when authenticated as attorney" do
      it "creates a document (can_edit? is true)" do
        post base_url,
          params: { document_type: "supporting_evidence", filename: "brief.pdf" }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:created)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        post base_url,
          params: { document_type: "rfe_notice", filename: "test.pdf" }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post base_url,
          params: { document_type: "rfe_notice", filename: "test.pdf" }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/cases/:case_id/rfe_documents/:id" do
    let!(:document) { create(:rfe_document, case: rfe_case, tenant: tenant, uploaded_by: admin) }

    context "when authenticated as admin" do
      it "deletes the document and returns 204" do
        expect {
          delete "#{base_url}/#{document.id}", headers: authenticated_headers(admin)
        }.to change(RfeDocument, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        delete "#{base_url}/#{document.id}", headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        delete "#{base_url}/#{document.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
