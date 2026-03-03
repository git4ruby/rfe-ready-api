class Api::V1::ReportsController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :require_admin_or_attorney!

  def dashboard
    period = params[:period] || "30d"
    result = ReportingService.new(tenant: current_user.tenant, period: period).call
    render json: { data: result }
  end

  private

  def require_admin_or_attorney!
    unless current_user.admin? || current_user.attorney?
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
