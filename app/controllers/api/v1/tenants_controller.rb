class Api::V1::TenantsController < Api::V1::BaseController
  skip_after_action :verify_policy_scoped
  skip_after_action :verify_authorized
  after_action :verify_authorized

  before_action :set_tenant

  # GET /api/v1/tenant
  def show
    authorize @tenant
    render json: { data: TenantSerializer.render_as_hash(@tenant, view: :extended) }
  end

  # PATCH/PUT /api/v1/tenant
  def update
    authorize @tenant

    @tenant.update!(tenant_params)
    render json: { data: TenantSerializer.render_as_hash(@tenant, view: :extended) }
  end

  private

  def set_tenant
    @tenant = current_user.tenant
  end

  def tenant_params
    params.require(:tenant).permit(
      :name,
      :data_retention_days,
      settings: {}
    )
  end
end
