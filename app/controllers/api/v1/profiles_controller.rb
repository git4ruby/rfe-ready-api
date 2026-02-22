class Api::V1::ProfilesController < Api::V1::BaseController
  skip_before_action :set_tenant
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /api/v1/profile
  def show
    render json: { data: UserSerializer.render_as_hash(current_user, view: :extended) }
  end

  # PATCH /api/v1/profile
  def update
    attrs = profile_params.to_h
    if attrs.key?("preferences")
      merged = (current_user.preferences || {}).merge(attrs.delete("preferences"))
      attrs["preferences"] = merged
    end
    current_user.update!(attrs)
    render json: { data: UserSerializer.render_as_hash(current_user, view: :extended) }
  end

  # PATCH /api/v1/profile/change_password
  def change_password
    unless current_user.valid_password?(params[:current_password])
      render json: { error: "Current password is incorrect." }, status: :unprocessable_entity
      return
    end

    if params[:password] != params[:password_confirmation]
      render json: { error: "Password confirmation does not match." }, status: :unprocessable_entity
      return
    end

    current_user.update!(password: params[:password], password_confirmation: params[:password_confirmation])
    render json: { meta: { message: "Password changed successfully." } }
  end

  private

  def profile_params
    params.require(:profile).permit(:first_name, :last_name, :bar_number,
      preferences: [:timezone, :dashboard_layout, :locale, :onboarding_completed,
                     :notify_case_assigned, :notify_deadline_approaching, :notify_draft_ready])
  end
end
