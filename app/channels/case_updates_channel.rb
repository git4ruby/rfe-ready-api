class CaseUpdatesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "case_updates_tenant_#{current_user.tenant_id}"
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
  end

  # Broadcast a case update to all users in a tenant
  def self.broadcast_update(tenant_id, type:, case_id:, case_number:, message:)
    ActionCable.server.broadcast("case_updates_tenant_#{tenant_id}", {
      id: SecureRandom.uuid,
      type: type,
      case_id: case_id,
      case_number: case_number,
      message: message,
      created_at: Time.current.iso8601
    })
  end
end
