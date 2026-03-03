class Api::V1::KnowledgeSearchController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /api/v1/knowledge/search?q=term&visa_type=H-1B&limit=10
  def search
    result = KnowledgeSearchService.new(
      query: params[:q].to_s.strip,
      tenant: current_user.tenant,
      visa_type: params[:visa_type].presence,
      limit: (params[:limit] || 10).to_i.clamp(1, 50)
    ).call

    render json: { data: result }
  end
end
