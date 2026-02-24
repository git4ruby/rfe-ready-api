class CreateEvidenceChecklists < ActiveRecord::Migration[8.0]
  def change
    create_table :evidence_checklists, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :case, type: :uuid, null: false, foreign_key: true
      t.references :rfe_section, type: :uuid, null: false, foreign_key: true

      t.integer :position, default: 0, null: false
      t.integer :priority, default: 0, null: false
      t.string :document_name, null: false
      t.text :description
      t.text :guidance

      t.boolean :is_collected, default: false
      t.references :linked_document, type: :uuid, foreign_key: { to_table: :rfe_documents }
      t.text :attorney_notes

      t.timestamps
    end

    add_index :evidence_checklists, [ :rfe_section_id, :position ]
    add_index :evidence_checklists, :priority
  end
end
