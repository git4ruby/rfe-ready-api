class NotificationMailer < ApplicationMailer
  def comment_mention(user, comment, rfe_case)
    @user = user
    @commenter = comment.user.full_name
    @case_number = rfe_case.case_number
    @comment_body = comment.body
    @case_url = case_url(rfe_case.id)

    mail(
      to: @user.email,
      subject: "You were mentioned in a comment on Case #{@case_number}"
    )
  end

  def case_status_change(user, rfe_case, old_status, new_status)
    @user = user
    @case_number = rfe_case.case_number
    @old_status = old_status
    @new_status = new_status
    @case_url = case_url(rfe_case.id)

    mail(
      to: @user.email,
      subject: "Case #{@case_number} status changed to #{new_status}"
    )
  end

  def document_uploaded(user, document, rfe_case)
    @user = user
    @uploader = document.uploaded_by.full_name
    @filename = document.filename
    @case_number = rfe_case.case_number
    @case_url = case_url(rfe_case.id)

    mail(
      to: @user.email,
      subject: "New document uploaded to Case #{@case_number}"
    )
  end

  def draft_ready(user, rfe_case)
    @user = user
    @case_number = rfe_case.case_number
    @case_url = case_url(rfe_case.id)

    mail(
      to: @user.email,
      subject: "Draft responses ready for review - Case #{@case_number}"
    )
  end

  private

  def case_url(case_id)
    host = default_url_options_host
    "#{host}/cases/#{case_id}"
  end

  def default_url_options_host
    host = Rails.application.config.action_mailer.default_url_options[:host]
    port = Rails.application.config.action_mailer.default_url_options[:port]
    scheme = Rails.env.production? ? "https" : "http"
    port_str = port ? ":#{port}" : ""
    "#{scheme}://#{host}#{port_str}"
  end
end
