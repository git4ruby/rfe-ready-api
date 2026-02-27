require "rails_helper"

RSpec.describe "Api::V1::CaseTemplates", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:headers) { auth_headers(admin) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/case_templates" do
    let!(:template1) { create(:case_template, tenant: tenant, name: "Alpha Template") }
    let!(:template2) { create(:case_template, tenant: tenant, name: "Beta Template") }

    context "when authenticated as admin" do
      it "returns templates ordered by name" do
        get "/api/v1/case_templates", headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(2)
        names = body["data"].map { |t| t["name"] }
        expect(names).to eq(["Alpha Template", "Beta Template"])
      end
    end

    context "when authenticated as attorney" do
      it "returns templates (index is allowed for all roles)" do
        get "/api/v1/case_templates", headers: auth_headers(attorney)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(2)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/case_templates"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/case_templates/:id" do
    let!(:template) { create(:case_template, tenant: tenant) }

    context "when authenticated as admin" do
      it "returns the template detail" do
        get "/api/v1/case_templates/#{template.id}", headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["id"]).to eq(template.id)
        expect(body["data"]["name"]).to eq(template.name)
        expect(body["data"]["visa_category"]).to eq(template.visa_category)
        expect(body["data"]["default_sections"]).to be_present
        expect(body["data"]["default_checklist"]).to be_present
      end
    end

    context "when authenticated as attorney" do
      it "returns the template (can_edit? is true for attorney)" do
        get "/api/v1/case_templates/#{template.id}", headers: auth_headers(attorney)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["id"]).to eq(template.id)
      end
    end

    context "when authenticated as viewer" do
      it "returns 403 (viewer cannot show)" do
        get "/api/v1/case_templates/#{template.id}", headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/case_templates/#{template.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/case_templates" do
    let(:valid_params) do
      {
        case_template: {
          name: "New H-1B Template",
          description: "A comprehensive template for H-1B RFE responses",
          visa_category: "H-1B",
          default_sections: [
            { title: "Specialty Occupation", description: "Prove specialty occupation" }
          ],
          default_checklist: [
            { item: "Degree evaluation", required: true }
          ],
          default_notes: "Notes for the template"
        }
      }
    end

    context "when authenticated as admin" do
      it "creates a template and returns 201" do
        expect {
          post "/api/v1/case_templates", params: valid_params, headers: headers, as: :json
        }.to change(CaseTemplate, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["name"]).to eq("New H-1B Template")
        expect(body["data"]["visa_category"]).to eq("H-1B")
        expect(body["data"]["default_sections"].length).to eq(1)
        expect(body["data"]["default_checklist"].length).to eq(1)
      end

      it "assigns the correct tenant" do
        post "/api/v1/case_templates", params: valid_params, headers: headers, as: :json

        created_template = CaseTemplate.last
        expect(created_template.tenant_id).to eq(tenant.id)
      end
    end

    context "when authenticated as attorney" do
      it "returns 403 (only admin can create)" do
        post "/api/v1/case_templates", params: valid_params, headers: auth_headers(attorney), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with invalid params (missing name)" do
      it "returns 422" do
        post "/api/v1/case_templates",
          params: { case_template: { name: "", visa_category: "H-1B", default_sections: [{ title: "X", description: "Y" }], default_checklist: [{ item: "Z", required: true }] } },
          headers: headers,
          as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "/api/v1/case_templates", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/case_templates/:id" do
    let!(:template) { create(:case_template, tenant: tenant) }

    context "when authenticated as admin" do
      it "updates the template" do
        patch "/api/v1/case_templates/#{template.id}",
          params: { case_template: { name: "Updated Template Name", description: "Updated description" } },
          headers: headers,
          as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["name"]).to eq("Updated Template Name")
        expect(body["data"]["description"]).to eq("Updated description")
      end
    end

    context "when authenticated as attorney" do
      it "returns 403 (only admin can update)" do
        patch "/api/v1/case_templates/#{template.id}",
          params: { case_template: { name: "Attorney Update" } },
          headers: auth_headers(attorney),
          as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when template does not exist" do
      it "returns 404" do
        patch "/api/v1/case_templates/00000000-0000-0000-0000-000000000000",
          params: { case_template: { name: "Not Found" } },
          headers: headers,
          as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "/api/v1/case_templates/#{template.id}",
          params: { case_template: { name: "No Auth" } },
          as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/case_templates/:id" do
    let!(:template) { create(:case_template, tenant: tenant) }

    context "when authenticated as admin" do
      it "destroys the template and returns 204" do
        expect {
          delete "/api/v1/case_templates/#{template.id}", headers: headers
        }.to change(CaseTemplate, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when authenticated as attorney" do
      it "returns 403 (only admin can destroy)" do
        delete "/api/v1/case_templates/#{template.id}", headers: auth_headers(attorney)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when template does not exist" do
      it "returns 404" do
        delete "/api/v1/case_templates/00000000-0000-0000-0000-000000000000", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        delete "/api/v1/case_templates/#{template.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
