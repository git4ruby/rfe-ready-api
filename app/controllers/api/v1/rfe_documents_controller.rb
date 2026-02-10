class Api::V1::RfeDocumentsController < Api::V1::BaseController
  before_action :set_case
  before_action :set_document, only: %i[show destroy]

  # GET /api/v1/cases/:case_id/rfe_documents
  def index
    authorize @case, :show?
    documents = policy_scope(RfeDocument).where(case_id: @case.id)
    render json: { data: RfeDocumentSerializer.render_as_hash(documents) }
  end

  # GET /api/v1/cases/:case_id/rfe_documents/:id
  def show
    authorize @document
    render json: { data: RfeDocumentSerializer.render_as_hash(@document) }
  end

  # POST /api/v1/cases/:case_id/rfe_documents
  def create
    @document = @case.rfe_documents.new(
      document_type: params[:document_type] || "supporting_evidence",
      tenant: current_user.tenant,
      uploaded_by: current_user
    )

    file = params[:file]
    if file.present?
      @document.file.attach(file)
      @document.filename = file.original_filename
      @document.content_type = file.content_type
      @document.file_size = file.size
    else
      @document.filename = params[:filename] || "untitled"
    end

    authorize @document
    @document.save!
    render json: { data: RfeDocumentSerializer.render_as_hash(@document) }, status: :created
  end

  # DELETE /api/v1/cases/:case_id/rfe_documents/:id
  def destroy
    authorize @document
    @document.destroy!
    head :no_content
  end

  private

  def set_case
    @case = RfeCase.find(params[:case_id])
  end

  def set_document
    @document = @case.rfe_documents.find(params[:id])
  end
end
