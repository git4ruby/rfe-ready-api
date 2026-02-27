class Api::V1::CaseTemplatesController < Api::V1::BaseController
  before_action :set_template, only: %i[show update destroy]

  def index
    templates = policy_scope(CaseTemplate).order(:name)
    render json: { data: CaseTemplateSerializer.render_as_hash(templates) }
  end

  def show
    authorize @template
    render json: { data: CaseTemplateSerializer.render_as_hash(@template) }
  end

  def create
    @template = CaseTemplate.new(template_params)
    @template.tenant = current_user.tenant
    authorize @template
    @template.save!
    render json: { data: CaseTemplateSerializer.render_as_hash(@template) }, status: :created
  end

  def update
    authorize @template
    @template.update!(template_params)
    render json: { data: CaseTemplateSerializer.render_as_hash(@template) }
  end

  def destroy
    authorize @template
    @template.destroy!
    head :no_content
  end

  private

  def set_template
    @template = CaseTemplate.find(params[:id])
  end

  def template_params
    params.require(:case_template).permit(:name, :description, :visa_category, :default_notes, default_sections: [:title, :description], default_checklist: [:item, :required])
  end
end
