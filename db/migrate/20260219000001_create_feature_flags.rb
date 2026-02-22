class CreateFeatureFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :feature_flags, id: :uuid do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.boolean :enabled, default: false, null: false
      t.string :allowed_roles, array: true, default: []
      t.string :allowed_plans, array: true, default: []

      t.timestamps
    end

    add_index :feature_flags, [:tenant_id, :name], unique: true
  end
end
