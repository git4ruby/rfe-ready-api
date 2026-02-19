class Api::V1::UsersController < Api::V1::BaseController
  include Pagy::Backend

  before_action :set_user, only: %i[show update resend_invitation]

  # GET /api/v1/users
  def index
    @pagy, users = pagy(policy_scope(User).order(:last_name, :first_name))
    render json: {
      data: UserSerializer.render_as_hash(users),
      meta: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/users/:id
  def show
    authorize @user
    render json: { data: UserSerializer.render_as_hash(@user, view: :extended) }
  end

  # POST /api/v1/users
  def create
    @user = User.new(create_user_params)
    @user.tenant = current_user.tenant
    @user.jti = SecureRandom.uuid
    @user.confirmed_at = Time.current
    authorize @user

    @user.save!
    UserMailer.welcome_email(@user, params[:user][:password]).deliver_later
    render json: { data: UserSerializer.render_as_hash(@user) }, status: :created
  end

  # PATCH/PUT /api/v1/users/:id
  def update
    authorize @user

    @user.update!(user_params)
    render json: { data: UserSerializer.render_as_hash(@user) }
  end

  # POST /api/v1/users/:id/resend_invitation
  def resend_invitation
    authorize @user, :resend_invitation?

    @user.send_confirmation_instructions
    render json: {
      data: { user_id: @user.id },
      meta: { message: "Invitation has been resent." }
    }
  end

  private

  def set_user
    @user = User.where(tenant: current_user.tenant).find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :role,
      :status,
      :bar_number
    )
  end

  def create_user_params
    params.require(:user).permit(
      :email,
      :password,
      :password_confirmation,
      :first_name,
      :last_name,
      :role,
      :bar_number
    )
  end
end
