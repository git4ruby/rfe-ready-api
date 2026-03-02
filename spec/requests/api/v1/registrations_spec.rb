require "rails_helper"

RSpec.describe "Api::V1::Registrations", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }

  describe "POST /api/v1/users" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          first_name: "Jane",
          last_name: "Doe",
          role: "paralegal"
        }
      }
    end

    context "as an admin" do
      before do
        # Stub mailer to avoid Redis/Sidekiq dependency
        allow(UserMailer).to receive(:welcome_email).and_return(double(deliver_later: true))
      end

      it "creates a new user successfully" do
        admin

        expect {
          post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(admin)
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)

        # Verify response structure
        expect(body).to have_key("data")
        expect(body["data"]).to have_key("id")
        expect(body["data"]["id"]).to_not be_nil

        # Verify created user in database
        new_user = User.find_by(email: "newuser@example.com")
        expect(new_user).to_not be_nil
        expect(new_user.first_name).to eq("Jane")
        expect(new_user.last_name).to eq("Doe")
        expect(new_user.role).to eq("paralegal")
        expect(new_user.tenant_id).to eq(tenant.id)
      end

      it "assigns the new user to the admin's tenant" do
        admin

        post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(admin)

        created_user = User.find_by(email: "newuser@example.com")
        expect(created_user.tenant_id).to eq(admin.tenant_id)
      end

      it "creates a user with attorney role and bar_number" do
        attorney_params = {
          user: {
            email: "attorney@example.com",
            password: "Password123!",
            password_confirmation: "Password123!",
            first_name: "John",
            last_name: "Smith",
            role: "attorney",
            bar_number: "1234567"
          }
        }

        admin

        expect {
          post "/api/v1/users", params: attorney_params.to_json, headers: authenticated_headers(admin)
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "returns 422 when email is missing" do
        invalid_params = valid_params.deep_merge(user: { email: "" })

        post "/api/v1/users", params: invalid_params.to_json, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Validation failed.")
        expect(body["details"]).to be_an(Array)
        expect(body["details"]).to include(a_string_matching(/email/i))
      end

      it "returns 422 when password is too short" do
        invalid_params = valid_params.deep_merge(user: { password: "short", password_confirmation: "short" })

        post "/api/v1/users", params: invalid_params.to_json, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Validation failed.")
        expect(body["details"]).to be_an(Array)
      end

      it "returns 422 when password confirmation does not match" do
        invalid_params = valid_params.deep_merge(user: { password_confirmation: "DifferentPassword123!" })

        post "/api/v1/users", params: invalid_params.to_json, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["details"]).to include(a_string_matching(/password/i))
      end

      it "returns 422 when first_name is missing" do
        invalid_params = valid_params.deep_merge(user: { first_name: "" })

        post "/api/v1/users", params: invalid_params.to_json, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["details"]).to include(a_string_matching(/first name/i))
      end

      it "returns 422 when email is already taken" do
        create(:user, email: "newuser@example.com", tenant: tenant)

        post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["details"]).to include(a_string_matching(/email/i))
      end
    end

    context "as a non-admin user" do
      it "returns 403 forbidden for attorney" do
        post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(attorney)

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("You are not authorized to perform this action.")
      end

      it "returns 403 forbidden for viewer" do
        viewer = create(:user, :viewer, tenant: tenant)

        post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 forbidden for paralegal" do
        paralegal = create(:user, :paralegal, tenant: tenant)

        post "/api/v1/users", params: valid_params.to_json, headers: authenticated_headers(paralegal)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post "/api/v1/users", params: valid_params.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
