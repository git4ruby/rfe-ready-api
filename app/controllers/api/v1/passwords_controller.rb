class Api::V1::PasswordsController < ApplicationController
  # POST /api/v1/users/password
  def create
    User.send_reset_password_instructions(email: params.dig(:user, :email))

    render json: {
      meta: { message: "If an account exists for that email, reset instructions have been sent." }
    }, status: :ok
  end

  # PUT/PATCH /api/v1/users/password
  def update
    user = User.reset_password_by_token(
      reset_password_token: params.dig(:user, :reset_password_token),
      password: params.dig(:user, :password),
      password_confirmation: params.dig(:user, :password_confirmation)
    )

    if user.errors.empty?
      user.unlock_access! if user.access_locked?
      render json: {
        meta: { message: "Password has been reset successfully. You can now sign in." }
      }, status: :ok
    else
      render json: {
        error: "Password reset failed.",
        details: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
end
