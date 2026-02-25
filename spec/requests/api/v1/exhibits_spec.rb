require "rails_helper"

RSpec.describe "Api::V1::Exhibits", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

  let(:base_url) { "/api/v1/cases/#{rfe_case.id}/exhibits" }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/cases/:case_id/exhibits" do
    let!(:exhibit1) { create(:exhibit, case: rfe_case, tenant: tenant, position: 1) }
    let!(:exhibit2) { create(:exhibit, case: rfe_case, tenant: tenant, position: 2) }
    let!(:exhibit3) { create(:exhibit, case: rfe_case, tenant: tenant, position: 3) }

    context "when authenticated as admin" do
      it "returns ordered exhibits for the case" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(3)

        positions = body["data"].map { |e| e["position"] }
        expect(positions).to eq(positions.sort)
      end
    end

    context "when authenticated as viewer" do
      it "returns exhibits (show? is allowed for all roles)" do
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

  describe "GET /api/v1/cases/:case_id/exhibits/:id" do
    let!(:exhibit) { create(:exhibit, case: rfe_case, tenant: tenant) }

    context "when authenticated" do
      it "returns the exhibit" do
        get "#{base_url}/#{exhibit.id}", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["id"]).to eq(exhibit.id)
      end
    end

    context "when exhibit does not exist" do
      it "returns 404" do
        get "#{base_url}/999999", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "#{base_url}/#{exhibit.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/cases/:case_id/exhibits" do
    let(:valid_params) do
      {
        exhibit: {
          label: "Exhibit A",
          title: "Degree Certificate",
          description: "Bachelor's degree from accredited university",
          position: 1
        }
      }
    end

    context "when authenticated as admin" do
      it "creates an exhibit and returns 201" do
        expect {
          post base_url,
            params: valid_params.to_json,
            headers: authenticated_headers(admin)
        }.to change(Exhibit, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["label"]).to eq("Exhibit A")
        expect(body["data"]["title"]).to eq("Degree Certificate")
      end

      it "assigns the correct tenant to the exhibit" do
        post base_url,
          params: valid_params.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:created)
        created_exhibit = Exhibit.last
        expect(created_exhibit.tenant_id).to eq(tenant.id)
      end
    end

    context "when authenticated as attorney" do
      it "creates an exhibit (can_edit? is true)" do
        post base_url,
          params: valid_params.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:created)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        post base_url,
          params: valid_params.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        post base_url,
          params: { exhibit: { label: nil, title: nil } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post base_url,
          params: valid_params.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/exhibits/:id" do
    let!(:exhibit) { create(:exhibit, case: rfe_case, tenant: tenant, title: "Original Title") }

    context "when authenticated as admin" do
      it "updates the exhibit" do
        patch "#{base_url}/#{exhibit.id}",
          params: { exhibit: { title: "Updated Title", description: "New description" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        exhibit.reload
        expect(exhibit.title).to eq("Updated Title")
        expect(exhibit.description).to eq("New description")
      end
    end

    context "when authenticated as attorney" do
      it "updates the exhibit (can_edit? is true)" do
        patch "#{base_url}/#{exhibit.id}",
          params: { exhibit: { title: "Attorney Update" } }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        exhibit.reload
        expect(exhibit.title).to eq("Attorney Update")
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        patch "#{base_url}/#{exhibit.id}",
          params: { exhibit: { title: "Viewer Update" } }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when exhibit does not exist" do
      it "returns 404" do
        patch "#{base_url}/999999",
          params: { exhibit: { title: "Not Found" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{exhibit.id}",
          params: { exhibit: { title: "No Auth" } }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/cases/:case_id/exhibits/:id" do
    let!(:exhibit) { create(:exhibit, case: rfe_case, tenant: tenant) }

    context "when authenticated as admin" do
      it "deletes the exhibit and returns 204" do
        expect {
          delete "#{base_url}/#{exhibit.id}", headers: authenticated_headers(admin)
        }.to change(Exhibit, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when authenticated as attorney" do
      it "deletes the exhibit (can_edit? is true for destroy)" do
        expect {
          delete "#{base_url}/#{exhibit.id}", headers: authenticated_headers(attorney)
        }.to change(Exhibit, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403" do
        delete "#{base_url}/#{exhibit.id}", headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when exhibit does not exist" do
      it "returns 404" do
        delete "#{base_url}/999999", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        delete "#{base_url}/#{exhibit.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/exhibits/reorder" do
    let!(:exhibit_a) { create(:exhibit, case: rfe_case, tenant: tenant, label: "Exhibit A", position: 0) }
    let!(:exhibit_b) { create(:exhibit, case: rfe_case, tenant: tenant, label: "Exhibit B", position: 1) }
    let!(:exhibit_c) { create(:exhibit, case: rfe_case, tenant: tenant, label: "Exhibit C", position: 2) }

    context "when authenticated as admin" do
      it "reorders exhibits by updating positions" do
        patch "#{base_url}/reorder",
          params: { ids: [exhibit_c.id, exhibit_a.id, exhibit_b.id] }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(exhibit_c.reload.position).to eq(0)
        expect(exhibit_a.reload.position).to eq(1)
        expect(exhibit_b.reload.position).to eq(2)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403 (update? requires can_edit?)" do
        patch "#{base_url}/reorder",
          params: { ids: [exhibit_c.id, exhibit_a.id, exhibit_b.id] }.to_json,
          headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/reorder",
          params: { ids: [exhibit_c.id, exhibit_a.id, exhibit_b.id] }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
