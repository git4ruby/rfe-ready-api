class Api::V1::ImportsController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :require_admin!

  # POST /api/v1/imports
  def create
    unless params[:file].present?
      render json: { error: "No file provided." }, status: :unprocessable_entity
      return
    end

    file = params[:file]
    unless file.content_type.in?(%w[text/csv application/vnd.ms-excel])
      render json: { error: "Invalid file type. Please upload a CSV file." }, status: :unprocessable_entity
      return
    end

    service = CsvImportService.new(
      file: file,
      tenant: current_user.tenant,
      user: current_user
    )
    result = service.call

    status = result[:failed] > 0 && result[:imported] > 0 ? :ok : (result[:imported] > 0 ? :created : :unprocessable_entity)
    render json: { data: result }, status: status
  end

  private

  def require_admin!
    unless current_user.admin?
      render json: { error: "You are not authorized to perform this action." }, status: :forbidden
    end
  end
end
