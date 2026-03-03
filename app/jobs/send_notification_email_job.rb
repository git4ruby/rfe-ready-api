class SendNotificationEmailJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(notification_type, user_id, tenant_id, params = {})
    ActsAsTenant.with_tenant(Tenant.find(tenant_id)) do
      user = User.find(user_id)

      return unless user_wants_notification?(user, notification_type)

      case notification_type
      when "comment_mention"
        comment = Comment.find(params["comment_id"])
        rfe_case = comment.case
        NotificationMailer.comment_mention(user, comment, rfe_case).deliver_now
      when "case_status_change"
        rfe_case = RfeCase.find(params["case_id"])
        NotificationMailer.case_status_change(user, rfe_case, params["old_status"], params["new_status"]).deliver_now
      when "document_uploaded"
        document = RfeDocument.find(params["document_id"])
        rfe_case = document.case
        NotificationMailer.document_uploaded(user, document, rfe_case).deliver_now
      when "draft_ready"
        rfe_case = RfeCase.find(params["case_id"])
        NotificationMailer.draft_ready(user, rfe_case).deliver_now
      end
    end
  end

  private

  def user_wants_notification?(user, notification_type)
    prefs = user.preferences.fetch("notifications", {})
    # Default to true if preference not set
    prefs.fetch(notification_type, true)
  end
end
