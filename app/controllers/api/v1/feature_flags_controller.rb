class Api::V1::FeatureFlagsController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /api/v1/feature_flags
  def index
    flags = FeatureFlag.for_tenant(current_user.tenant)
    result = {}
    flags.each do |flag|
      result[flag.name] = FeatureFlag.enabled?(flag.name, current_user)
    end
    render json: { data: result }
  end
end
