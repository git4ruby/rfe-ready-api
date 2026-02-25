require "rails_helper"

RSpec.describe "Api::V1::RfeSections", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

  let(:base_url) { "/api/v1/cases/#{rfe_case.id}/rfe_sections" }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/cases/:case_id/rfe_sections" do
    let!(:section1) { create(:rfe_section, case: rfe_case, tenant: tenant, position: 1) }
    let!(:section2) { create(:rfe_section, case: rfe_case, tenant: tenant, position: 2) }
    let!(:section3) { create(:rfe_section, case: rfe_case, tenant: tenant, position: 3) }

    context "when authenticated as admin" do
      it "returns ordered sections for the case" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(3)

        positions = body["data"].map { |s| s["position"] }
        expect(positions).to eq(positions.sort)
      end
    end

    context "when authenticated as viewer" do
      it "returns sections (show? is allowed for all roles)" do
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

  describe "GET /api/v1/cases/:case_id/rfe_sections/:id" do
    let!(:section) { create(:rfe_section, case: rfe_case, tenant: tenant) }

    context "when authenticated" do
      it "returns the section" do
        get "#{base_url}/#{section.id}", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["id"]).to eq(section.id)
      end
    end

    context "when section does not exist" do
      it "returns 404" do
        get "#{base_url}/999999", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "#{base_url}/#{section.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/rfe_sections/:id" do
    let!(:section) { create(:rfe_section, case: rfe_case, tenant: tenant, confidence_score: 0.5) }

    context "when authenticated as admin" do
      it "updates the section attributes" do
        patch "#{base_url}/#{section.id}",
          params: { rfe_section: { confidence_score: 0.99, position: 5 } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        section.reload
        expect(section.confidence_score).to eq(0.99)
        expect(section.position).to eq(5)
      end
    end

    context "when authenticated as attorney" do
      it "updates the section (can_edit? is true)" do
        patch "#{base_url}/#{section.id}",
          params: { rfe_section: { confidence_score: 0.75 } }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        section.reload
        expect(section.confidence_score).to eq(0.75)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        patch "#{base_url}/#{section.id}",
          params: { rfe_section: { confidence_score: 0.1 } }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{section.id}",
          params: { rfe_section: { confidence_score: 0.1 } }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/cases/:case_id/rfe_sections/:id/reclassify" do
    let!(:section) { create(:rfe_section, case: rfe_case, tenant: tenant, section_type: :general) }

    context "when authenticated as admin" do
      it "updates the section_type" do
        post "#{base_url}/#{section.id}/reclassify",
          params: { section_type: "specialty_occupation" }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        section.reload
        expect(section.section_type).to eq("specialty_occupation")
      end
    end

    context "when authenticated as attorney" do
      it "reclassifies the section (can_edit? is true)" do
        post "#{base_url}/#{section.id}/reclassify",
          params: { section_type: "specialty_occupation" }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        section.reload
        expect(section.section_type).to eq("specialty_occupation")
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        post "#{base_url}/#{section.id}/reclassify",
          params: { section_type: "specialty_occupation" }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when section does not exist" do
      it "returns 404" do
        post "#{base_url}/999999/reclassify",
          params: { section_type: "specialty_occupation" }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "#{base_url}/#{section.id}/reclassify",
          params: { section_type: "specialty_occupation" }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
