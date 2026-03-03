require "rails_helper"

RSpec.describe "Api::V1::DraftResponses", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:rfe_section) { create(:rfe_section, case: rfe_case, tenant: tenant) }

  let(:base_url) { "/api/v1/cases/#{rfe_case.id}/draft_responses" }

  before do
    ActsAsTenant.current_tenant = tenant
    ActiveJob::Base.queue_adapter = :test
  end

  describe "GET /api/v1/cases/:case_id/draft_responses" do
    let!(:draft1) { create(:draft_response, case: rfe_case, tenant: tenant, rfe_section: rfe_section, position: 1) }
    let!(:draft2) { create(:draft_response, case: rfe_case, tenant: tenant, rfe_section: rfe_section, position: 2) }

    context "when authenticated as admin" do
      it "returns ordered draft responses for the case" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(2)
      end
    end

    context "when authenticated as viewer" do
      it "returns draft responses (show? is allowed for all roles)" do
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
  end

  describe "GET /api/v1/cases/:case_id/draft_responses/:id" do
    let!(:draft) { create(:draft_response, case: rfe_case, tenant: tenant, rfe_section: rfe_section) }

    context "when authenticated" do
      it "returns the draft response" do
        get "#{base_url}/#{draft.id}", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["id"]).to eq(draft.id)
      end
    end

    context "when draft response does not exist" do
      it "returns 404" do
        get "#{base_url}/999999", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "#{base_url}/#{draft.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/cases/:case_id/draft_responses/generate_all" do
    let(:generate_url) { "#{base_url}/generate_all" }

    context "when authenticated as admin with existing sections" do
      before { create(:rfe_section, case: rfe_case, tenant: tenant) }

      it "enqueues GenerateDraftsJob and returns 202" do
        post generate_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body["data"]["status"]).to eq("queued")
        expect(body["data"]["message"]).to eq("Draft generation started.")
        expect(GenerateDraftsJob).to have_been_enqueued.with(rfe_case.id, tenant.id)
      end
    end

    context "when authenticated as admin with no sections" do
      it "returns 422 with error message" do
        post generate_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to include("No RFE sections found")
      end
    end

    context "when authenticated as attorney with existing sections" do
      before { create(:rfe_section, case: rfe_case, tenant: tenant) }

      it "enqueues GenerateDraftsJob (can_edit? is true for update?)" do
        post generate_url, headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:accepted)
        expect(GenerateDraftsJob).to have_been_enqueued
      end
    end

    context "when authenticated as viewer" do
      before { create(:rfe_section, case: rfe_case, tenant: tenant) }

      it "returns 403" do
        post generate_url, headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post generate_url

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/draft_responses/:id" do
    let!(:draft) { create(:draft_response, case: rfe_case, tenant: tenant, rfe_section: rfe_section) }

    context "when authenticated as admin" do
      it "updates the edited_content" do
        patch "#{base_url}/#{draft.id}",
          params: { draft_response: { edited_content: "Updated content from admin" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        draft.reload
        expect(draft.edited_content).to eq("Updated content from admin")
      end
    end

    context "when authenticated as paralegal" do
      it "updates the draft response (can_edit? is true)" do
        patch "#{base_url}/#{draft.id}",
          params: { draft_response: { edited_content: "Paralegal edits" } }.to_json,
          headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:ok)
        draft.reload
        expect(draft.edited_content).to eq("Paralegal edits")
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        patch "#{base_url}/#{draft.id}",
          params: { draft_response: { edited_content: "Viewer edit" } }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{draft.id}",
          params: { draft_response: { edited_content: "No auth" } }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/draft_responses/:id/approve" do
    let!(:draft) { create(:draft_response, case: rfe_case, tenant: tenant, rfe_section: rfe_section) }

    context "when authenticated as attorney" do
      it "approves the draft response and changes status to approved" do
        patch "#{base_url}/#{draft.id}/approve",
          params: { attorney_feedback: "Looks good" }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        draft.reload
        expect(draft.status).to eq("approved")
      end
    end

    context "when authenticated as admin" do
      it "approves the draft response (attorney? includes admin)" do
        patch "#{base_url}/#{draft.id}/approve",
          params: { attorney_feedback: "Admin approved" }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        draft.reload
        expect(draft.status).to eq("approved")
      end
    end

    context "when authenticated as paralegal" do
      it "returns 403 (approve? requires attorney role)" do
        patch "#{base_url}/#{draft.id}/approve",
          params: { attorney_feedback: "Paralegal attempt" }.to_json,
          headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        patch "#{base_url}/#{draft.id}/approve",
          params: { attorney_feedback: "Viewer attempt" }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{draft.id}/approve",
          params: { attorney_feedback: "No auth" }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/cases/:case_id/draft_responses/:id/regenerate" do
    let!(:draft) { create(:draft_response, case: rfe_case, tenant: tenant, rfe_section: rfe_section) }

    context "when authenticated as admin" do
      it "enqueues GenerateDraftsJob with section_id and returns 202" do
        post "#{base_url}/#{draft.id}/regenerate", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body["data"]["status"]).to eq("queued")
        expect(body["data"]["message"]).to eq("Regeneration started.")
        expect(GenerateDraftsJob).to have_been_enqueued.with(
          rfe_case.id, tenant.id, section_id: rfe_section.id
        )
      end
    end

    context "when authenticated as attorney" do
      it "enqueues regeneration job (can_edit? is true)" do
        post "#{base_url}/#{draft.id}/regenerate", headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:accepted)
        expect(GenerateDraftsJob).to have_been_enqueued
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        post "#{base_url}/#{draft.id}/regenerate", headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "#{base_url}/#{draft.id}/regenerate"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
