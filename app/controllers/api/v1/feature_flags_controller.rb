class Api::V1::FeatureFlagsController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :require_admin!, only: %i[manage create update destroy]
  before_action :set_feature_flag, only: %i[update destroy]

  # GET /api/v1/feature_flags
  def index
    flags = FeatureFlag.for_tenant(current_user.tenant)
    result = {}
    flags.each do |flag|
      result[flag.name] = FeatureFlag.enabled?(flag.name, current_user)
    end
    render json: { data: result }
  end

  # GET /api/v1/feature_flags/manage
  def manage
    flags = FeatureFlag.for_tenant(current_user.tenant).order(:name)
    render json: {
      data: flags.map { |f| serialize_flag(f) }
    }
  end

  # POST /api/v1/feature_flags
  def create
    flag = FeatureFlag.new(feature_flag_params)
    flag.tenant = current_user.tenant
    flag.save!
    render json: { data: serialize_flag(flag) }, status: :created
  end

  # PATCH /api/v1/feature_flags/:id
  def update
    @feature_flag.update!(feature_flag_params)
    render json: { data: serialize_flag(@feature_flag) }
  end

  # DELETE /api/v1/feature_flags/:id
  def destroy
    @feature_flag.destroy!
    head :no_content
  end

  private

  def set_feature_flag
    @feature_flag = FeatureFlag.find(params[:id])
  end

  def require_admin!
    unless current_user.admin?
      render json: { error: "You are not authorized to perform this action." }, status: :forbidden
    end
  end

  def feature_flag_params
    params.require(:feature_flag).permit(:name, :enabled, allowed_roles: [], allowed_plans: [])
  end

  def serialize_flag(flag)
    {
      id: flag.id,
      name: flag.name,
      enabled: flag.enabled,
      allowed_roles: flag.allowed_roles,
      allowed_plans: flag.allowed_plans,
      created_at: flag.created_at,
      updated_at: flag.updated_at
    }
  end
end
