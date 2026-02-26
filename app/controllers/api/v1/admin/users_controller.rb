class Api::V1::Admin::UsersController < Api::V1::Admin::BaseController
  include Pagy::Backend

  before_action :set_tenant
  before_action :set_user, only: %i[show update destroy]

  # GET /api/v1/admin/tenants/:tenant_id/users
  def index
    @pagy, users = pagy(@tenant.users.order(:last_name, :first_name))
    render json: {
      data: UserSerializer.render_as_hash(users),
      meta: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/admin/tenants/:tenant_id/users/:id
  def show
    render json: { data: UserSerializer.render_as_hash(@user) }
  end

  # POST /api/v1/admin/tenants/:tenant_id/users
  def create
    user = User.new(user_params)
    user.tenant = @tenant
    user.jti = SecureRandom.uuid
    user.confirmed_at = Time.current

    user.save!
    UserMailer.welcome_email(user, params[:user][:password]).deliver_later
    render json: {
      data: UserSerializer.render_as_hash(user),
      meta: { message: "User created successfully for #{@tenant.name}." }
    }, status: :created
  end

  # PATCH /api/v1/admin/tenants/:tenant_id/users/:id
  def update
    @user.update!(update_user_params)
    render json: {
      data: UserSerializer.render_as_hash(@user),
      meta: { message: "User updated successfully." }
    }
  end

  # DELETE /api/v1/admin/tenants/:tenant_id/users/:id
  def destroy
    @user.update!(status: :inactive)
    render json: {
      data: UserSerializer.render_as_hash(@user),
      meta: { message: "User deactivated successfully." }
    }
  end

  private

  def set_tenant
    @tenant = Tenant.real_tenants.find(params[:tenant_id])
  end

  def set_user
    @user = @tenant.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :email, :password, :password_confirmation,
      :first_name, :last_name, :role, :bar_number
    )
  end

  def update_user_params
    params.require(:user).permit(
      :first_name, :last_name, :role, :bar_number, :status
    )
  end
end
