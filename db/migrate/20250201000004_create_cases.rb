class CreateCases < ActiveRecord::Migration[8.0]
  def change
    create_table :cases, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :assigned_attorney, type: :uuid, foreign_key: { to_table: :users }

      t.string :case_number, null: false
      t.string :uscis_receipt_number
      t.string :visa_type, default: "H-1B", null: false
      t.string :status, default: "draft", null: false

      t.string :petitioner_name
      t.text :beneficiary_name_ciphertext
      t.string :beneficiary_name_bidx

      t.date :rfe_received_date
      t.date :rfe_deadline

      t.text :notes
      t.jsonb :metadata, default: {}

      t.boolean :attorney_reviewed, default: false
      t.datetime :attorney_reviewed_at
      t.datetime :exported_at
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :cases, [ :tenant_id, :case_number ], unique: true
    add_index :cases, :uscis_receipt_number
    add_index :cases, :status
    add_index :cases, :beneficiary_name_bidx
    add_index :cases, :rfe_deadline
  end
end
