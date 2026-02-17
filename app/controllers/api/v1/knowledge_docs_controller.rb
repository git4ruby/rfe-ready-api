class Api::V1::KnowledgeDocsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :set_knowledge_doc, only: %i[show update destroy]

  # GET /api/v1/knowledge_docs
  def index
    scope = policy_scope(KnowledgeDoc).order(created_at: :desc)
    scope = scope.where(doc_type: params[:doc_type]) if params[:doc_type].present?
    scope = scope.for_visa(params[:visa_type]) if params[:visa_type].present?
    scope = scope.for_category(params[:rfe_category]) if params[:rfe_category].present?
    scope = scope.active if params[:active_only].present?

    @pagy, docs = pagy(scope, items: 10)
    render json: {
      data: KnowledgeDocSerializer.render_as_hash(docs),
      meta: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/knowledge_docs/:id
  def show
    authorize @knowledge_doc
    render json: { data: KnowledgeDocSerializer.render_as_hash(@knowledge_doc, view: :detail) }
  end

  # POST /api/v1/knowledge_docs
  def create
    @knowledge_doc = KnowledgeDoc.new(knowledge_doc_params)
    @knowledge_doc.uploaded_by = current_user
    authorize @knowledge_doc

    @knowledge_doc.save!
    render json: { data: KnowledgeDocSerializer.render_as_hash(@knowledge_doc) }, status: :created
  end

  # PATCH/PUT /api/v1/knowledge_docs/:id
  def update
    authorize @knowledge_doc

    @knowledge_doc.update!(knowledge_doc_params)
    render json: { data: KnowledgeDocSerializer.render_as_hash(@knowledge_doc) }
  end

  # DELETE /api/v1/knowledge_docs/:id
  def destroy
    authorize @knowledge_doc

    @knowledge_doc.destroy!
    head :no_content
  end

  private

  def set_knowledge_doc
    @knowledge_doc = KnowledgeDoc.find(params[:id])
  end

  def knowledge_doc_params
    params.require(:knowledge_doc).permit(
      :doc_type,
      :title,
      :content,
      :visa_type,
      :rfe_category,
      :is_active,
      :file
    )
  end
end
