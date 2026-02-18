class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: {
        data: {
          id: resource.id,
          type: "user",
          attributes: {
            email: resource.email,
            first_name: resource.first_name,
            last_name: resource.last_name,
            role: resource.role,
            tenant_id: resource.tenant_id,
            is_super_admin: resource.is_super_admin
          }
        },
        meta: { message: "Logged in successfully." }
      }, status: :ok
    else
      render json: {
        error: "Invalid email or password."
      }, status: :unauthorized
    end
  end

  def respond_to_on_destroy
    if current_user
      render json: { meta: { message: "Logged out successfully." } }, status: :ok
    else
      render json: { error: "Could not log out." }, status: :unauthorized
    end
  end
end
