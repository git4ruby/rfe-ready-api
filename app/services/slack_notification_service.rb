class SlackNotificationService
  def initialize(tenant:, event:, payload:)
    @tenant = tenant
    @event = event
    @payload = payload
  end

  def call
    integrations = SlackIntegration.where(tenant: @tenant, active: true)
                                   .where("? = ANY(events)", @event)
    integrations.find_each do |integration|
      SendSlackNotificationJob.perform_later(integration.id, @event, @payload.to_json)
    end
  end
end
