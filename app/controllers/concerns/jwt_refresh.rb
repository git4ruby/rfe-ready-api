# frozen_string_literal: true

module JwtRefresh
  extend ActiveSupport::Concern

  included do
    after_action :refresh_jwt_token
  end

  private

  def refresh_jwt_token
    return unless current_user
    return if request.method == "DELETE" && request.path.match?(%r{/users/sign_out})

    # Generate new JWT token with fresh expiration
    token = Warden::JWTAuth::UserEncoder.new.call(
      current_user,
      :user,
      nil
    ).first

    # Add to response headers
    response.headers["Authorization"] = "Bearer #{token}"
  end
end
