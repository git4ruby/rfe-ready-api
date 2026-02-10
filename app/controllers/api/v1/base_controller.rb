class Api::V1::BaseController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_tenant

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from AASM::InvalidTransition, with: :invalid_transition

  private

  def set_tenant
    return unless current_user

    ActsAsTenant.current_tenant = current_user.tenant
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
