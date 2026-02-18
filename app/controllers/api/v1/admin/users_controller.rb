class Api::V1::Admin::UsersController < Api::V1::Admin::BaseController
  include Pagy::Backend

  # GET /api/v1/admin/tenants/:tenant_id/users
  def index
    tenant = Tenant.real_tenants.find(params[:tenant_id])
    @pagy, users = pagy(User.where(tenant: tenant).order(:last_name, :first_name))
    render json: {
      data: UserSerializer.render_as_hash(users),
      meta: pagy_metadata(@pagy)
    }
  end

  # POST /api/v1/admin/tenants/:tenant_id/users
  def create
    tenant = Tenant.real_tenants.find(params[:tenant_id])

    user = User.new(user_params)
    user.tenant = tenant
    user.jti = SecureRandom.uuid
    user.confirmed_at = Time.current

    user.save!
    render json: {
      data: UserSerializer.render_as_hash(user),
      meta: { message: "User created successfully for #{tenant.name}." }
    }, status: :created
  end

  private

  def user_params
    params.require(:user).permit(
      :email, :password, :password_confirmation,
      :first_name, :last_name, :role, :bar_number
    )
  end
end
