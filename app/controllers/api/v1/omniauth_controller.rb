class Api::V1::OmniauthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  # GET/POST /api/v1/auth/:provider/callback
  def callback
    auth = request.env["omniauth.auth"]

    unless auth
      redirect_to_frontend(error: "Authentication failed.")
      return
    end

    email = auth.info.email
    user = User.find_by(email: email)

    unless user
      redirect_to_frontend(error: "No account found for #{email}. Please contact your administrator.")
      return
    end

    unless user.account_active?
      redirect_to_frontend(error: "Your account is inactive.")
      return
    end

    # Sign in and generate JWT
    sign_in(user)
    token = request.env["warden-jwt_auth.token"]

    redirect_to_frontend(
      token: token,
      user_id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      tenant_id: user.tenant_id,
      is_super_admin: user.is_super_admin
    )
  end

  # GET/POST /api/v1/auth/failure
  def failure
    redirect_to_frontend(error: params[:message] || "Authentication failed.")
  end

  private

  def redirect_to_frontend(params = {})
    frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    query = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
    redirect_to "#{frontend_url}/sso/callback?#{query}", allow_other_host: true
  end
end
