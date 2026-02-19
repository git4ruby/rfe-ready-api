class Api::V1::HealthController < Api::V1::BaseController
  skip_before_action :authenticate_user!
  skip_before_action :set_tenant
  skip_before_action :set_current_attributes
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    checks = {
      database: database_connected?,
      redis: redis_connected?
    }

    status = checks.values.all? ? :ok : :service_unavailable

    render json: {
      status: status == :ok ? "ok" : "degraded",
      version: "1.0.0",
      timestamp: Time.current.iso8601,
      checks: checks
    }, status: status
  end

  private

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  def redis_connected?
    Redis.new.ping == "PONG"
  rescue StandardError
    false
  end
end
