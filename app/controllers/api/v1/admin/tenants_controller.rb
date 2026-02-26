class Api::V1::Admin::TenantsController < Api::V1::Admin::BaseController
  include Pagy::Backend

  before_action :set_tenant, only: %i[show update destroy change_status change_plan]

  # GET /api/v1/admin/tenants
  def index
    scope = Tenant.real_tenants.order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(plan: params[:plan]) if params[:plan].present?
    scope = scope.where("name ILIKE ?", "%#{Tenant.sanitize_sql_like(params[:search])}%") if params[:search].present?

    @pagy, tenants = pagy(scope)
    render json: {
      data: Admin::TenantSerializer.render_as_hash(tenants),
      meta: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/admin/tenants/:id
  def show
    render json: {
      data: Admin::TenantSerializer.render_as_hash(@tenant, view: :detailed)
    }
  end

  # POST /api/v1/admin/tenants
  def create
    tenant = Tenant.new(tenant_params)
    tenant.save!
    render json: {
      data: Admin::TenantSerializer.render_as_hash(tenant)
    }, status: :created
  end

  # PATCH/PUT /api/v1/admin/tenants/:id
  def update
    @tenant.update!(tenant_params)
    render json: {
      data: Admin::TenantSerializer.render_as_hash(@tenant, view: :detailed)
    }
  end

  # DELETE /api/v1/admin/tenants/:id
  def destroy
    if @tenant.platform_tenant?
      render json: { error: "Cannot delete the platform tenant." }, status: :forbidden
      return
    end
    @tenant.destroy!
    render json: { meta: { message: "Tenant deleted successfully." } }
  end

  # PATCH /api/v1/admin/tenants/:id/change_status
  def change_status
    new_status = params[:status]
    unless Tenant.statuses.key?(new_status)
      render json: { error: "Invalid status: #{new_status}" }, status: :unprocessable_entity
      return
    end

    @tenant.update!(status: new_status)
    render json: {
      data: Admin::TenantSerializer.render_as_hash(@tenant, view: :detailed),
      meta: { message: "Tenant status changed to #{new_status}." }
    }
  end

  # PATCH /api/v1/admin/tenants/:id/change_plan
  def change_plan
    new_plan = params[:plan]
    unless Tenant.plans.key?(new_plan)
      render json: { error: "Invalid plan: #{new_plan}" }, status: :unprocessable_entity
      return
    end

    @tenant.update!(plan: new_plan)
    render json: {
      data: Admin::TenantSerializer.render_as_hash(@tenant, view: :detailed),
      meta: { message: "Tenant plan changed to #{new_plan}." }
    }
  end

  private

  def set_tenant
    @tenant = Tenant.real_tenants.find(params[:id])
  end

  def tenant_params
    params.require(:tenant).permit(:name, :plan, :status, :data_retention_days, :two_factor_required, settings: {})
  end
end
