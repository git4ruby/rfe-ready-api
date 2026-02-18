class Api::V1::Admin::DashboardController < Api::V1::Admin::BaseController
  # GET /api/v1/admin/dashboard
  def index
    real_tenants = Tenant.real_tenants

    render json: {
      data: {
        total_tenants: real_tenants.count,
        tenants_by_status: real_tenants.group(:status).count,
        tenants_by_plan: real_tenants.group(:plan).count,
        total_users: User.where(is_super_admin: false).count,
        total_cases: RfeCase.unscoped.count,
        cases_by_status: RfeCase.unscoped.group(:status).count,
        recent_tenants: Admin::TenantSerializer.render_as_hash(
          real_tenants.order(created_at: :desc).limit(5)
        ),
        growth: {
          tenants_this_month: real_tenants.where("created_at >= ?", Time.current.beginning_of_month).count,
          users_this_month: User.where(is_super_admin: false)
                                .where("created_at >= ?", Time.current.beginning_of_month).count,
          cases_this_month: RfeCase.unscoped
                                   .where("created_at >= ?", Time.current.beginning_of_month).count
        }
      }
    }
  end
end
