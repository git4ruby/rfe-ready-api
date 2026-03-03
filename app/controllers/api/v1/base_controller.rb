class Api::V1::BaseController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_tenant
  before_action :enforce_two_factor!
  before_action :set_current_attributes

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from AASM::InvalidTransition, with: :invalid_transition

  private

  def set_tenant
    return unless current_user

    if current_user.super_admin?
      render json: { error: "Super admins must use the platform admin endpoints." }, status: :forbidden
      return
    end

    ActsAsTenant.current_tenant = current_user.tenant
  end

  def enforce_two_factor!
    return unless current_user
    return if two_factor_exempt_path?
    return unless current_user.tenant&.two_factor_required?
    return if current_user.otp_required_for_login?

    render json: {
      error: "Two-factor authentication is required by your organization. Please set up 2FA.",
      code: "2fa_required"
    }, status: :forbidden
  end

  def two_factor_exempt_path?
    exempt_patterns = [
      %r{\A/api/v1/two_factor(/|\z)},
      %r{\A/api/v1/users/sign_in},
      %r{\A/api/v1/users/sign_out}
    ]
    exempt_patterns.any? { |pattern| request.path.match?(pattern) }
  end

  def set_current_attributes
    Current.user = current_user
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
  end

  def forbidden(exception)
    render json: { error: "You are not authorized to perform this action." }, status: :forbidden
  end

  def not_found
    render json: { error: "Resource not found." }, status: :not_found
  end

  def invalid_transition(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def unprocessable(exception)
    render json: {
      error: "Validation failed.",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def pagy_metadata(pagy)
    {
      current_page: pagy.page,
      total_pages: pagy.pages,
      total_count: pagy.count,
      per_page: pagy.items
    }
  end
end
