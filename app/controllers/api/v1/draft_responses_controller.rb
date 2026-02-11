class Api::V1::DraftResponsesController < Api::V1::BaseController
  before_action :set_case
  before_action :set_draft_response, only: %i[show update approve regenerate]

  # GET /api/v1/cases/:case_id/draft_responses
  def index
    authorize @case, :show?
    drafts = policy_scope(DraftResponse).where(case_id: @case.id).ordered
    render json: { data: DraftResponseSerializer.render_as_hash(drafts) }
  end

  # GET /api/v1/cases/:case_id/draft_responses/:id
  def show
    authorize @draft_response
    render json: { data: DraftResponseSerializer.render_as_hash(@draft_response, view: :detail) }
  end

  # POST /api/v1/cases/:case_id/draft_responses/generate_all
  def generate_all
    authorize @case, :update?

    unless @case.rfe_sections.any?
      render json: { error: "No RFE sections found. Run analysis first." }, status: :unprocessable_entity
      return
    end

    GenerateDraftsJob.perform_later(@case.id, ActsAsTenant.current_tenant.id)
    render json: { data: { status: "queued", message: "Draft generation started." } }, status: :accepted
  end

  # PATCH/PUT /api/v1/cases/:case_id/draft_responses/:id
  def update
    authorize @draft_response

    @draft_response.update!(draft_response_params)
    render json: { data: DraftResponseSerializer.render_as_hash(@draft_response) }
  end

  # PATCH /api/v1/cases/:case_id/draft_responses/:id/approve
  def approve
    authorize @draft_response, :approve?

    @draft_response.approve!(feedback: params[:attorney_feedback])
    render json: { data: DraftResponseSerializer.render_as_hash(@draft_response) }
  end

  # POST /api/v1/cases/:case_id/draft_responses/:id/regenerate
  def regenerate
    authorize @draft_response, :regenerate?

    GenerateDraftsJob.perform_later(
      @case.id,
      ActsAsTenant.current_tenant.id,
      section_id: @draft_response.rfe_section_id
    )
    render json: {
      data: { status: "queued", message: "Regeneration started." }
    }, status: :accepted
  end

  private

  def set_case
    @case = RfeCase.find(params[:case_id])
  end

  def set_draft_response
    @draft_response = @case.draft_responses.find(params[:id])
  end

  def draft_response_params
    params.require(:draft_response).permit(
      :edited_content,
      :attorney_feedback
    )
  end
end
