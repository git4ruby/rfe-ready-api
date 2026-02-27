class Api::V1::SlackIntegrationsController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :require_admin!
  before_action :set_integration, only: %i[update destroy test_notification]

  def index
    integrations = SlackIntegration.where(tenant: current_user.tenant).order(created_at: :desc)
    render json: { data: integrations }
  end

  def create
    integration = SlackIntegration.new(integration_params)
    integration.tenant = current_user.tenant
    integration.save!
    render json: { data: integration }, status: :created
  end

  def update
    @integration.update!(integration_params)
    render json: { data: @integration }
  end

  def destroy
    @integration.destroy!
    head :no_content
  end

  def test_notification
    SlackNotificationService.new(
      tenant: current_user.tenant,
      event: "case.created",
      payload: { case_number: "TEST-001", visa_type: "H-1B", petitioner_name: "Test Corp" }
    ).call
    render json: { data: { message: "Test notification queued." } }
  end

  private

  def require_admin!
    render json: { error: "Forbidden" }, status: :forbidden unless current_user.admin?
  end

  def set_integration
    @integration = SlackIntegration.find(params[:id])
  end

  def integration_params
    params.require(:slack_integration).permit(:webhook_url, :channel_name, :active, events: [])
  end
end
