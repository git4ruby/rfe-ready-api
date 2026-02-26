class Api::V1::WebhooksController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :require_admin!
  before_action :set_webhook, only: %i[show update destroy test_delivery]

  def index
    webhooks = Webhook.where(tenant: current_user.tenant).order(created_at: :desc)
    render json: { data: webhooks.as_json(except: [:secret]) }
  end

  def show
    render json: { data: @webhook.as_json(except: [:secret]) }
  end

  def create
    webhook = Webhook.new(webhook_params)
    webhook.tenant = current_user.tenant
    webhook.save!
    render json: { data: webhook.as_json(except: [:secret]) }, status: :created
  end

  def update
    @webhook.update!(webhook_params)
    render json: { data: @webhook.as_json(except: [:secret]) }
  end

  def destroy
    @webhook.destroy!
    head :no_content
  end

  def test_delivery
    WebhookDeliveryService.new(
      tenant: current_user.tenant,
      event: "webhook.test",
      payload: { message: "Test webhook delivery", webhook_id: @webhook.id, timestamp: Time.current }
    ).call
    render json: { data: { message: "Test webhook queued for delivery." } }
  end

  private

  def set_webhook
    @webhook = Webhook.find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(:url, :secret, :active, :description, events: [])
  end

  def require_admin!
    unless current_user.admin?
      render json: { error: "You are not authorized to perform this action." }, status: :forbidden
    end
  end
end
