class SendSlackNotificationJob < ApplicationJob
  queue_as :notifications
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(integration_id, event, payload_json)
    integration = SlackIntegration.find_by(id: integration_id)
    return unless integration&.active?

    payload = JSON.parse(payload_json)
    message = format_message(event, payload)

    uri = URI(integration.webhook_url)
    response = Net::HTTP.post(uri, { text: message }.to_json, "Content-Type" => "application/json")

    unless response.is_a?(Net::HTTPSuccess)
      raise "Slack notification failed: #{response.code} #{response.message}"
    end
  end

  private

  def format_message(event, payload)
    case event
    when "case.created"
      ":new: *New RFE Case Created*\nCase: #{payload['case_number']}\nVisa: #{payload['visa_type']}\nPetitioner: #{payload['petitioner_name']}"
    when "case.status_changed"
      ":arrows_counterclockwise: *Case Status Changed*\nCase: #{payload['case_number']}\n#{payload['old_status']} → #{payload['new_status']}"
    when "case.archived"
      ":file_cabinet: *Case Archived*\nCase: #{payload['case_number']}"
    when "document.uploaded"
      ":page_facing_up: *Document Uploaded*\nCase: #{payload['case_number']}\nFile: #{payload['filename']}"
    when "draft.approved"
      ":white_check_mark: *Draft Approved*\nCase: #{payload['case_number']}\nSection: #{payload['section_title']}"
    else
      ":bell: *#{event}*\n#{payload.to_json}"
    end
  end
end
