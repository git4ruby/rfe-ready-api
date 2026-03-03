require "rails_helper"

RSpec.describe "Api::V1::Health", type: :request do
  describe "GET /api/v1/health" do
    it "returns 200 when all services are healthy" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
      redis_instance = instance_double(Redis, ping: "PONG")
      allow(Redis).to receive(:new).and_return(redis_instance)

      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body["version"]).to eq("1.0.0")
      expect(body["timestamp"]).to be_present
      expect(body["checks"]["database"]).to be true
      expect(body["checks"]["redis"]).to be true
    end

    it "returns service_unavailable when database is down" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
      redis_instance = instance_double(Redis, ping: "PONG")
      allow(Redis).to receive(:new).and_return(redis_instance)

      get "/api/v1/health"

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("degraded")
      expect(body["checks"]["database"]).to be false
      expect(body["checks"]["redis"]).to be true
    end

    it "returns service_unavailable when redis is down" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
      allow(Redis).to receive(:new).and_raise(StandardError, "Connection refused")

      get "/api/v1/health"

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("degraded")
      expect(body["checks"]["database"]).to be true
      expect(body["checks"]["redis"]).to be false
    end

    it "returns service_unavailable when all services are down" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
      allow(Redis).to receive(:new).and_raise(StandardError, "Connection refused")

      get "/api/v1/health"

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("degraded")
      expect(body["checks"]["database"]).to be false
      expect(body["checks"]["redis"]).to be false
    end

    it "does not require authentication" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
      redis_instance = instance_double(Redis, ping: "PONG")
      allow(Redis).to receive(:new).and_return(redis_instance)

      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
    end

    it "includes a valid ISO8601 timestamp" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
      redis_instance = instance_double(Redis, ping: "PONG")
      allow(Redis).to receive(:new).and_return(redis_instance)

      get "/api/v1/health"

      body = JSON.parse(response.body)
      expect { Time.iso8601(body["timestamp"]) }.not_to raise_error
    end
  end
end
