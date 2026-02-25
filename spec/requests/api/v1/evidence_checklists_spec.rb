require "rails_helper"

RSpec.describe "Api::V1::EvidenceChecklists", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:rfe_section) { create(:rfe_section, case: rfe_case, tenant: tenant) }

  let(:base_url) { "/api/v1/cases/#{rfe_case.id}/evidence_checklists" }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/cases/:case_id/evidence_checklists" do
    let!(:item1) { create(:evidence_checklist, case: rfe_case, tenant: tenant, rfe_section: rfe_section, position: 1) }
    let!(:item2) { create(:evidence_checklist, case: rfe_case, tenant: tenant, rfe_section: rfe_section, position: 2) }
    let!(:item3) { create(:evidence_checklist, case: rfe_case, tenant: tenant, rfe_section: rfe_section, position: 3) }

    context "when authenticated as admin" do
      it "returns ordered checklist items for the case" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(3)

        positions = body["data"].map { |i| i["position"] }
        expect(positions).to eq(positions.sort)
      end
    end

    context "when authenticated as viewer" do
      it "returns checklist items (show? is allowed for all roles)" do
        get base_url, headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(3)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get base_url

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/evidence_checklists/:id" do
    let!(:checklist_item) do
      create(:evidence_checklist,
        case: rfe_case,
        tenant: tenant,
        rfe_section: rfe_section,
        document_name: "Original Document",
        priority: :required)
    end

    context "when authenticated as admin" do
      it "updates the checklist item attributes" do
        patch "#{base_url}/#{checklist_item.id}",
          params: {
            evidence_checklist: {
              document_name: "Updated Document",
              description: "New description",
              priority: "recommended"
            }
          }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.document_name).to eq("Updated Document")
        expect(checklist_item.description).to eq("New description")
        expect(checklist_item.priority).to eq("recommended")
      end
    end

    context "when authenticated as attorney" do
      it "updates the checklist item (can_edit? is true)" do
        patch "#{base_url}/#{checklist_item.id}",
          params: { evidence_checklist: { document_name: "Attorney Update" } }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.document_name).to eq("Attorney Update")
      end
    end

    context "when authenticated as paralegal" do
      it "updates the checklist item (can_edit? is true)" do
        patch "#{base_url}/#{checklist_item.id}",
          params: { evidence_checklist: { document_name: "Paralegal Update" } }.to_json,
          headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.document_name).to eq("Paralegal Update")
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        patch "#{base_url}/#{checklist_item.id}",
          params: { evidence_checklist: { document_name: "Viewer Update" } }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when checklist item does not exist" do
      it "returns 404" do
        patch "#{base_url}/999999",
          params: { evidence_checklist: { document_name: "Not Found" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{checklist_item.id}",
          params: { evidence_checklist: { document_name: "No Auth" } }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/evidence_checklists/:id/toggle_collected" do
    let!(:checklist_item) do
      create(:evidence_checklist,
        case: rfe_case,
        tenant: tenant,
        rfe_section: rfe_section,
        is_collected: false)
    end

    context "when authenticated as admin" do
      it "toggles is_collected from false to true" do
        patch "#{base_url}/#{checklist_item.id}/toggle_collected",
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.is_collected).to be(true)
      end

      it "toggles is_collected from true to false" do
        checklist_item.update!(is_collected: true)

        patch "#{base_url}/#{checklist_item.id}/toggle_collected",
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.is_collected).to be(false)
      end
    end

    context "when authenticated as attorney" do
      it "toggles the collected status (can_edit? is true)" do
        patch "#{base_url}/#{checklist_item.id}/toggle_collected",
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.is_collected).to be(true)
      end
    end

    context "when authenticated as paralegal" do
      it "toggles the collected status (can_edit? is true)" do
        patch "#{base_url}/#{checklist_item.id}/toggle_collected",
          headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:ok)
        checklist_item.reload
        expect(checklist_item.is_collected).to be(true)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        patch "#{base_url}/#{checklist_item.id}/toggle_collected",
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when checklist item does not exist" do
      it "returns 404" do
        patch "#{base_url}/999999/toggle_collected",
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{checklist_item.id}/toggle_collected"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
