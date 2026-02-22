class CreateBackups < ActiveRecord::Migration[8.0]
  def change
    create_table :backups, id: :uuid do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.references :user, null: true, foreign_key: true, type: :uuid
      t.integer :status, default: 0, null: false
      t.string :file_url
      t.bigint :file_size
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :backups, [:tenant_id, :created_at]
  end
end
