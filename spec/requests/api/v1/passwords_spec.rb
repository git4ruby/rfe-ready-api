require "rails_helper"

RSpec.describe "Api::V1::Passwords", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant, password: "Password123!") }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  describe "POST /api/v1/users/password" do
    context "with an existing email" do
      it "returns 200 with a generic message" do
        post "/api/v1/users/password",
             params: { user: { email: user.email } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["meta"]["message"]).to match(/reset instructions/i)
      end
    end

    context "with a non-existent email" do
      it "returns 200 with the same generic message for security" do
        post "/api/v1/users/password",
             params: { user: { email: "nonexistent@example.com" } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["meta"]["message"]).to match(/reset instructions/i)
      end
    end
  end

  describe "PUT /api/v1/users/password" do
    context "with a valid reset token and matching passwords" do
      it "returns 200 and allows login with the new password" do
        raw_token, enc_token = Devise.token_generator.generate(User, :reset_password_token)
        user.update!(reset_password_token: enc_token, reset_password_sent_at: Time.current)

        put "/api/v1/users/password",
            params: {
              user: {
                reset_password_token: raw_token,
                password: "NewPassword456!",
                password_confirmation: "NewPassword456!"
              }
            }.to_json,
            headers: json_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["meta"]["message"]).to match(/reset successfully/i)

        # Verify user can sign in with the new password
        post "/api/v1/users/sign_in",
             params: { user: { email: user.email, password: "NewPassword456!" } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid reset token" do
      it "returns 422" do
        put "/api/v1/users/password",
            params: {
              user: {
                reset_password_token: "invalidtoken",
                password: "NewPassword456!",
                password_confirmation: "NewPassword456!"
              }
            }.to_json,
            headers: json_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to be_present
        expect(body["details"]).to be_an(Array)
      end
    end

    context "with mismatched passwords" do
      it "returns 422" do
        raw_token, enc_token = Devise.token_generator.generate(User, :reset_password_token)
        user.update!(reset_password_token: enc_token, reset_password_sent_at: Time.current)

        put "/api/v1/users/password",
            params: {
              user: {
                reset_password_token: raw_token,
                password: "NewPassword456!",
                password_confirmation: "DifferentPassword789!"
              }
            }.to_json,
            headers: json_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to be_present
        expect(body["details"]).to be_an(Array)
      end
    end
  end
end
