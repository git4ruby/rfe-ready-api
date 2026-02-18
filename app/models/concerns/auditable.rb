module Auditable
  extend ActiveSupport::Concern

  included do
    after_create_commit  { create_audit_log("create") }
    after_update_commit  { create_audit_log("update") }
    after_destroy_commit { create_audit_log("destroy") }
  end

  private

  def create_audit_log(action)
    return unless ActsAsTenant.current_tenant

    AuditLog.create!(
      tenant: ActsAsTenant.current_tenant,
      user: Current.user,
      action: action,
      auditable: self,
      changes_data: action == "create" ? {} : saved_changes.except("updated_at", "created_at"),
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  rescue => e
    Rails.logger.error("Auditable: Failed to create audit log: #{e.message}")
  end
end
