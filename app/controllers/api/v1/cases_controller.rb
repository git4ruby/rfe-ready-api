class Api::V1::CasesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :set_case, only: %i[show update destroy start_analysis analysis_status assign_attorney mark_reviewed mark_responded archive reopen export activity]

  # GET /api/v1/cases
  def index
    @pagy, cases = pagy(policy_scope(RfeCase).order(created_at: :desc))
    render json: {
      data: CaseSerializer.render_as_hash(cases),
      meta: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/cases/:id
  def show
    authorize @case
    render json: { data: CaseSerializer.render_as_hash(@case, view: :detail) }
  end

  # POST /api/v1/cases
  def create
    @case = RfeCase.new(case_params)
    @case.created_by = current_user
    authorize @case

    @case.save!
    render json: { data: CaseSerializer.render_as_hash(@case) }, status: :created
  end

  # PATCH/PUT /api/v1/cases/:id
  def update
    authorize @case

    @case.update!(case_params)
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # DELETE /api/v1/cases/:id
  def destroy
    authorize @case

    @case.destroy!
    head :no_content
  end

  # POST /api/v1/cases/:id/start_analysis
  def start_analysis
    authorize @case, :start_analysis?

    # Validate RFE notice documents exist
    unless @case.rfe_documents.rfe_notices.any?
      render json: { error: "Please upload at least one RFE notice document before starting analysis." }, status: :unprocessable_entity
      return
    end

    @case.start_analysis!
    @case.update_column(:metadata, @case.metadata.merge(analysis_progress: "queued", analysis_updated_at: Time.current))

    AnalyzeRfeDocumentJob.perform_later(@case.id, ActsAsTenant.current_tenant.id)
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # GET /api/v1/cases/:id/analysis_status
  def analysis_status
    authorize @case, :show?

    progress = @case.metadata["analysis_progress"] || "unknown"
    render json: {
      data: {
        status: @case.status,
        progress: progress,
        sections_count: @case.rfe_sections.count,
        error: @case.metadata["analysis_error"]
      }
    }
  end

  # PATCH /api/v1/cases/:id/assign_attorney
  def assign_attorney
    authorize @case, :assign_attorney?

    attorney = User.find(params[:attorney_id])
    @case.update!(assigned_attorney: attorney)
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # PATCH /api/v1/cases/:id/mark_reviewed
  def mark_reviewed
    authorize @case, :mark_reviewed?

    @case.complete_analysis!
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # PATCH /api/v1/cases/:id/mark_responded
  def mark_responded
    authorize @case, :mark_responded?

    @case.mark_responded!
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # POST /api/v1/cases/:id/archive
  def archive
    authorize @case, :archive?

    @case.archive!
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # POST /api/v1/cases/:id/reopen
  def reopen
    authorize @case, :reopen?

    @case.reopen!
    render json: { data: CaseSerializer.render_as_hash(@case) }
  end

  # POST /api/v1/cases/:id/export
  def export
    authorize @case, :export?

    format = params[:format_type]&.to_sym || :pdf
    unless %i[pdf docx zip].include?(format)
      render json: { error: "Unsupported format. Use 'pdf' or 'docx'." }, status: :unprocessable_entity
      return
    end

    service = ExportService.new(@case, format: format)
    data = service.call

    @case.update_column(:exported_at, Time.current)

    send_data data,
      filename: service.filename,
      type: service.content_type,
      disposition: "attachment"
  end

  # POST /api/v1/cases/bulk_update_status
  def bulk_update_status
    ids = params[:ids]
    action_name = params[:action_name]

    unless %w[archive reopen].include?(action_name)
      render json: { error: "Invalid action. Use 'archive' or 'reopen'." }, status: :unprocessable_entity
      return
    end

    cases = policy_scope(RfeCase).where(id: ids)
    success = 0
    failed = 0

    cases.find_each do |rfe_case|
      begin
        authorize rfe_case, :"#{action_name}?"
        rfe_case.send(:"#{action_name}!")
        success += 1
      rescue StandardError
        failed += 1
      end
    end

    render json: { data: { success: success, failed: failed, total: ids.size } }
  end

  # GET /api/v1/cases/:id/activity
  def activity
    authorize @case, :show?
    logs = AuditLog.for_record(@case).recent.includes(:user).limit(50)
    render json: { data: AuditLogSerializer.render_as_hash(logs) }
  end

  private

  def set_case
    @case = RfeCase.find(params[:id])
  end

  def case_params
    params.require(:rfe_case).permit(
      :case_number,
      :uscis_receipt_number,
      :visa_type,
      :petitioner_name,
      :beneficiary_name,
      :rfe_received_date,
      :rfe_deadline,
      :notes
    )
  end
end
