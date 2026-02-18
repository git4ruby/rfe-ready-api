class Api::V1::Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_super_admin!
  before_action :set_current_attributes

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable

  private

  def require_super_admin!
    unless current_user&.super_admin?
      render json: { error: "Not authorized. Super admin access required." }, status: :forbidden
    end
  end

  def set_current_attributes
    Current.user = current_user
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
  end

  def not_found
    render json: { error: "Resource not found." }, status: :not_found
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
