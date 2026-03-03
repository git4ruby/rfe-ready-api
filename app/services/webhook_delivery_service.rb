class WebhookDeliveryService
  def initialize(tenant:, event:, payload:)
    @tenant = tenant
    @event = event
    @payload = payload
  end

  def call
    webhooks = Webhook.where(tenant: @tenant, active: true)
                      .where("? = ANY(events)", @event)
    webhooks.find_each do |webhook|
      DeliverWebhookJob.perform_later(webhook.id, @event, @payload.to_json)
    end
  end
end
