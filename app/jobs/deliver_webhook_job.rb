class DeliverWebhookJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(webhook_id, event, payload_json)
    webhook = Webhook.find_by(id: webhook_id)
    return unless webhook&.active?

    signature = generate_signature(payload_json, webhook.secret)

    response = Net::HTTP.post(
      URI(webhook.url),
      payload_json,
      {
        "Content-Type" => "application/json",
        "X-Webhook-Event" => event,
        "X-Webhook-Signature" => signature,
        "User-Agent" => "RFEReady-Webhooks/1.0"
      }
    )

    unless response.is_a?(Net::HTTPSuccess)
      raise "Webhook delivery failed: #{response.code} #{response.message}"
    end
  end

  private

  def generate_signature(payload, secret)
    return "" if secret.blank?
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, payload)}"
  end
end
