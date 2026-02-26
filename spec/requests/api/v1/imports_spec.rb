require "rails_helper"

RSpec.describe "Api::V1::Imports", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin_user) { create(:user, :admin, tenant: tenant) }
  let(:attorney_user) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal_user) { create(:user, :paralegal, tenant: tenant) }

  let(:valid_csv_content) { "case_number,visa_type,petitioner_name\nRFE-001,H-1B,Acme Corp\nRFE-002,L-1A,Globex Inc\n" }

  def csv_upload(content, content_type: "text/csv", filename: "import.csv")
    file = Tempfile.new(["import", ".csv"])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, content_type)
  end

  def auth_headers_for(user)
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/imports" do
    context "with valid CSV and admin user" do
      it "returns 201 and imports all rows" do
        post "/api/v1/imports",
          params: { file: csv_upload(valid_csv_content) },
          headers: auth_headers_for(admin_user)

        expect(response).to have_http_status(:created)

        body = JSON.parse(response.body)
        expect(body["data"]["total"]).to eq(2)
        expect(body["data"]["imported"]).to eq(2)
        expect(body["data"]["failed"]).to eq(0)
        expect(body["data"]["errors"]).to be_empty
      end

      it "creates RfeCase records in the database" do
        expect {
          post "/api/v1/imports",
            params: { file: csv_upload(valid_csv_content) },
            headers: auth_headers_for(admin_user)
        }.to change(RfeCase, :count).by(2)
      end
    end

    context "with partial success (some valid, some invalid rows)" do
      let(:mixed_csv_content) do
        "case_number,visa_type,petitioner_name\n" \
        "RFE-001,H-1B,Acme Corp\n" \
        ",,Missing Everything\n" \
        "RFE-003,L-1A,Globex Inc\n"
      end

      it "returns 200 with import results showing partial success" do
        post "/api/v1/imports",
          params: { file: csv_upload(mixed_csv_content) },
          headers: auth_headers_for(admin_user)

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body["data"]["total"]).to eq(3)
        expect(body["data"]["imported"]).to eq(2)
        expect(body["data"]["failed"]).to eq(1)
        expect(body["data"]["errors"].size).to eq(1)
      end
    end

    context "with all rows failing" do
      let(:invalid_csv_content) do
        "case_number,visa_type,petitioner_name\n" \
        ",,\n" \
        ",,\n"
      end

      it "returns 422 when no rows are imported" do
        post "/api/v1/imports",
          params: { file: csv_upload(invalid_csv_content) },
          headers: auth_headers_for(admin_user)

        expect(response).to have_http_status(:unprocessable_entity)

        body = JSON.parse(response.body)
        expect(body["data"]["total"]).to eq(2)
        expect(body["data"]["imported"]).to eq(0)
        expect(body["data"]["failed"]).to eq(2)
      end
    end

    context "when no file is provided" do
      it "returns 422 with an error message" do
        post "/api/v1/imports",
          params: {},
          headers: auth_headers_for(admin_user)

        expect(response).to have_http_status(:unprocessable_entity)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("No file provided.")
      end
    end

    context "with an invalid file type" do
      it "returns 422 with an error message" do
        post "/api/v1/imports",
          params: { file: csv_upload(valid_csv_content, content_type: "application/pdf", filename: "import.pdf") },
          headers: auth_headers_for(admin_user)

        expect(response).to have_http_status(:unprocessable_entity)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Invalid file type. Please upload a CSV file.")
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/imports",
          params: { file: csv_upload(valid_csv_content) }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is an attorney (non-admin)" do
      it "returns 403" do
        post "/api/v1/imports",
          params: { file: csv_upload(valid_csv_content) },
          headers: auth_headers_for(attorney_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is a paralegal (non-admin)" do
      it "returns 403" do
        post "/api/v1/imports",
          params: { file: csv_upload(valid_csv_content) },
          headers: auth_headers_for(paralegal_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with import results structure" do
      it "returns data with total, imported, failed, and errors keys" do
        post "/api/v1/imports",
          params: { file: csv_upload(valid_csv_content) },
          headers: auth_headers_for(admin_user)

        body = JSON.parse(response.body)
        expect(body).to have_key("data")
        expect(body["data"]).to have_key("total")
        expect(body["data"]).to have_key("imported")
        expect(body["data"]).to have_key("failed")
        expect(body["data"]).to have_key("errors")
      end
    end
  end
end
