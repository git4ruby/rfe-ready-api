class UserSerializer < Blueprinter::Base
  identifier :id
  fields :email, :first_name, :last_name, :role, :status, :bar_number, :created_at

  view :extended do
    field :preferences
    field :otp_required_for_login
    field :sign_in_count
    field :current_sign_in_at
    association :tenant, blueprint: TenantSerializer
  end
end
