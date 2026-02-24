class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true

      t.string :action, null: false
      t.string :auditable_type, null: false
      t.uuid :auditable_id, null: false
      t.jsonb :changes_data, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, [ :auditable_type, :auditable_id ]
    add_index :audit_logs, [ :tenant_id, :created_at ]
    add_index :audit_logs, :action
  end
end
