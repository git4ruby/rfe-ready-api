require "rails_helper"

RSpec.describe "Api::V1::Comments", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }

  let(:base_url) { "/api/v1/cases/#{rfe_case.id}/comments" }

  before { ActsAsTenant.current_tenant = tenant }

  describe "GET /api/v1/cases/:case_id/comments" do
    let!(:comment1) { create(:comment, case: rfe_case, tenant: tenant, user: admin, body: "First comment") }
    let!(:comment2) { create(:comment, case: rfe_case, tenant: tenant, user: attorney, body: "Second comment") }
    let!(:reply) { create(:comment, case: rfe_case, tenant: tenant, user: admin, body: "Reply to first", parent: comment1) }

    context "when authenticated as admin" do
      it "returns top-level comments with replies" do
        get base_url, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(2) # only top-level
        first = body["data"].find { |c| c["body"] == "First comment" }
        expect(first["replies"].length).to eq(1)
        expect(first["replies"].first["body"]).to eq("Reply to first")
      end

      it "includes user_name in response" do
        get base_url, headers: authenticated_headers(admin)

        body = JSON.parse(response.body)
        expect(body["data"].first["user_name"]).to be_present
      end
    end

    context "when authenticated as viewer" do
      it "returns comments (all roles can view)" do
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

  describe "POST /api/v1/cases/:case_id/comments" do
    let(:valid_params) do
      { comment: { body: "This is a test comment" } }
    end

    context "when authenticated as admin" do
      it "creates a comment and returns 201" do
        expect {
          post base_url,
            params: valid_params.to_json,
            headers: authenticated_headers(admin)
        }.to change(Comment, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["body"]).to eq("This is a test comment")
        expect(body["data"]["user_name"]).to eq(admin.full_name)
      end

      it "assigns the correct tenant and user" do
        post base_url,
          params: valid_params.to_json,
          headers: authenticated_headers(admin)

        created_comment = Comment.last
        expect(created_comment.tenant_id).to eq(tenant.id)
        expect(created_comment.user_id).to eq(admin.id)
      end
    end

    context "when creating a reply" do
      let!(:parent_comment) { create(:comment, case: rfe_case, tenant: tenant, user: admin) }

      it "creates a reply with parent_id" do
        post base_url,
          params: { comment: { body: "This is a reply", parent_id: parent_comment.id } }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["parent_id"]).to eq(parent_comment.id)
      end
    end

    context "when mentioning users" do
      it "stores mentioned_user_ids" do
        post base_url,
          params: { comment: { body: "Hey @attorney check this", mentioned_user_ids: [attorney.id] } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["mentioned_user_ids"]).to include(attorney.id)
      end
    end

    context "when authenticated as attorney" do
      it "creates a comment (can_edit? is true)" do
        post base_url,
          params: valid_params.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:created)
      end
    end

    context "when authenticated as paralegal" do
      it "creates a comment (can_edit? is true)" do
        post base_url,
          params: valid_params.to_json,
          headers: authenticated_headers(paralegal)

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

    context "with invalid params (empty body)" do
      it "returns 422" do
        post base_url,
          params: { comment: { body: "" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post base_url, params: valid_params.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cases/:case_id/comments/:id" do
    let!(:comment) { create(:comment, case: rfe_case, tenant: tenant, user: attorney, body: "Original body") }

    context "when authenticated as the comment author" do
      it "updates the comment" do
        patch "#{base_url}/#{comment.id}",
          params: { comment: { body: "Updated body" } }.to_json,
          headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.body).to eq("Updated body")
      end
    end

    context "when authenticated as admin (not author)" do
      it "updates the comment (admin can edit any comment)" do
        patch "#{base_url}/#{comment.id}",
          params: { comment: { body: "Admin edit" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.body).to eq("Admin edit")
      end
    end

    context "when authenticated as another non-admin user" do
      it "returns 403" do
        patch "#{base_url}/#{comment.id}",
          params: { comment: { body: "Paralegal edit" } }.to_json,
          headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when comment does not exist" do
      it "returns 404" do
        patch "#{base_url}/999999",
          params: { comment: { body: "Not Found" } }.to_json,
          headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "#{base_url}/#{comment.id}",
          params: { comment: { body: "No Auth" } }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/cases/:case_id/comments/:id" do
    let!(:comment) { create(:comment, case: rfe_case, tenant: tenant, user: attorney) }

    context "when authenticated as the comment author" do
      it "deletes the comment and returns 204" do
        expect {
          delete "#{base_url}/#{comment.id}", headers: authenticated_headers(attorney)
        }.to change(Comment, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when authenticated as admin (not author)" do
      it "deletes the comment (admin can delete any comment)" do
        expect {
          delete "#{base_url}/#{comment.id}", headers: authenticated_headers(admin)
        }.to change(Comment, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when authenticated as another non-admin user" do
      it "returns 403" do
        delete "#{base_url}/#{comment.id}", headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when comment does not exist" do
      it "returns 404" do
        delete "#{base_url}/999999", headers: authenticated_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        delete "#{base_url}/#{comment.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
