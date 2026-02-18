class Api::V1::KnowledgeDocsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :set_knowledge_doc, only: %i[show update destroy]

  # GET /api/v1/knowledge_docs
  def index
    scope = policy_scope(KnowledgeDoc).order(created_at: :desc)
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(doc_type: params[:doc_type]) if params[:doc_type].present?
    scope = scope.for_visa(params[:visa_type]) if params[:visa_type].present?
    scope = scope.for_category(params[:rfe_category]) if params[:rfe_category].present?
    scope = scope.active if params[:active_only].present?

    @pagy, docs = pagy(scope, items: 10)

    # Knowledge stats for the page header
    all_docs = policy_scope(KnowledgeDoc)
    embedded_ids = Embedding.where(tenant: current_user.tenant, embeddable_type: "KnowledgeDoc")
                            .distinct.pluck(:embeddable_id)

    render json: {
      data: KnowledgeDocSerializer.render_as_hash(docs),
      meta: pagy_metadata(@pagy).merge(
        stats: {
          total_docs: all_docs.count,
          by_doc_type: all_docs.group(:doc_type).count,
          embedded_count: embedded_ids.size,
          pending_count: all_docs.count - embedded_ids.size
        }
      )
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
    GenerateEmbeddingsJob.perform_later(@knowledge_doc.id, current_user.tenant_id)
    render json: { data: KnowledgeDocSerializer.render_as_hash(@knowledge_doc) }, status: :created
  end

  # PATCH/PUT /api/v1/knowledge_docs/:id
  def update
    authorize @knowledge_doc

    @knowledge_doc.update!(knowledge_doc_params)
    GenerateEmbeddingsJob.perform_later(@knowledge_doc.id, current_user.tenant_id)
    render json: { data: KnowledgeDocSerializer.render_as_hash(@knowledge_doc) }
  end

  # POST /api/v1/knowledge_docs/bulk_create
  def bulk_create
    files = params[:files] || []
    authorize KnowledgeDoc, :create?

    docs = []
    files.each do |file|
      doc = KnowledgeDoc.new(
        title: file.original_filename.sub(/\.[^.]+\z/, '').titleize,
        doc_type: params[:doc_type] || "firm_knowledge",
        visa_type: params[:visa_type].presence,
        rfe_category: params[:rfe_category].presence,
        is_active: true,
        uploaded_by: current_user,
        file: file
      )
      doc.save!
      GenerateEmbeddingsJob.perform_later(doc.id, current_user.tenant_id)
      docs << doc
    end

    render json: {
      data: KnowledgeDocSerializer.render_as_hash(docs),
      meta: { count: docs.size }
    }, status: :created
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
