class AddTwoFactorRequiredToTenants < ActiveRecord::Migration[8.0]
  def change
    add_column :tenants, :two_factor_required, :boolean, default: false, null: false
  end
end
