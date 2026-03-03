require "rails_helper"

RSpec.describe "API Documentation", type: :request do
  describe "GET /api-docs" do
    it "returns the Swagger UI page" do
      get "/api-docs"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("swagger-ui")
      expect(response.body).to include("RFE Ready API Documentation")
    end
  end

  describe "GET /openapi.yaml" do
    it "serves the OpenAPI spec file" do
      get "/openapi.yaml"

      expect(response).to have_http_status(:ok)
    end
  end
end
