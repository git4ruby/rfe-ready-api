class Api::V1::ExhibitsController < Api::V1::BaseController
  before_action :set_case
  before_action :set_exhibit, only: %i[show update destroy]

  # GET /api/v1/cases/:case_id/exhibits
  def index
    authorize @case, :show?
    exhibits = policy_scope(Exhibit).where(case_id: @case.id).ordered
    render json: { data: ExhibitSerializer.render_as_hash(exhibits) }
  end

  # GET /api/v1/cases/:case_id/exhibits/:id
  def show
    authorize @exhibit
    render json: { data: ExhibitSerializer.render_as_hash(@exhibit) }
  end

  # POST /api/v1/cases/:case_id/exhibits
  def create
    @exhibit = @case.exhibits.new(exhibit_params)
    @exhibit.tenant = current_user.tenant
    authorize @exhibit

    @exhibit.save!
    render json: { data: ExhibitSerializer.render_as_hash(@exhibit) }, status: :created
  end

  # PATCH/PUT /api/v1/cases/:case_id/exhibits/:id
  def update
    authorize @exhibit

    @exhibit.update!(exhibit_params)
    render json: { data: ExhibitSerializer.render_as_hash(@exhibit) }
  end

  # DELETE /api/v1/cases/:case_id/exhibits/:id
  def destroy
    authorize @exhibit

    @exhibit.destroy!
    head :no_content
  end

  # PATCH /api/v1/cases/:case_id/exhibits/reorder
  def reorder
    authorize @case, :update?

    ids = params[:ids] || []
    ActiveRecord::Base.transaction do
      ids.each_with_index do |id, index|
        @case.exhibits.where(id: id).update_all(position: index)
      end
    end

    exhibits = @case.exhibits.ordered
    render json: { data: ExhibitSerializer.render_as_hash(exhibits) }
  end

  private

  def set_case
    @case = RfeCase.find(params[:case_id])
  end

  def set_exhibit
    @exhibit = @case.exhibits.find(params[:id])
  end

  def exhibit_params
    params.require(:exhibit).permit(
      :label,
      :title,
      :description,
      :position,
      :page_range,
      :rfe_document_id
    )
  end
end
