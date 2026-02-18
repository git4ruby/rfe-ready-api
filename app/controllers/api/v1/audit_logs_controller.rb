class Api::V1::AuditLogsController < Api::V1::BaseController
  include Pagy::Backend

  # GET /api/v1/audit_logs
  def index
    authorize AuditLog

    scope = policy_scope(AuditLog).recent.includes(:user, :auditable)

    scope = scope.by_action(params[:action_type]) if params[:action_type].present?
    scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

    @pagy, logs = pagy(scope, items: 20)
    render json: {
      data: AuditLogSerializer.render_as_hash(logs),
      meta: pagy_metadata(@pagy)
    }
  end
end
