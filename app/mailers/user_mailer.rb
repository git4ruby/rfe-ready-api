class UserMailer < ApplicationMailer
  def welcome_email(user, temp_password)
    @user = user
    @temp_password = temp_password
    @login_url = "#{default_url_options_host}/login"
    @organization = user.tenant.name

    mail(
      to: @user.email,
      subject: "Welcome to RFE Ready - Your account is ready"
    )
  end

  private

  def default_url_options_host
    host = Rails.application.config.action_mailer.default_url_options[:host]
    port = Rails.application.config.action_mailer.default_url_options[:port]
    scheme = Rails.env.production? ? "https" : "http"
    port_str = port ? ":#{port}" : ""
    "#{scheme}://#{host}#{port_str}"
  end
end
