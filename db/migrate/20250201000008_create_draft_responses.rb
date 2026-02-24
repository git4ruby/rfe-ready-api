class CreateDraftResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_responses, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :case, type: :uuid, null: false, foreign_key: true
      t.references :rfe_section, type: :uuid, null: false, foreign_key: true

      t.integer :position, default: 0, null: false
      t.string :title
      t.text :ai_generated_content
      t.text :edited_content
      t.text :final_content
      t.integer :status, default: 0, null: false
      t.integer :version, default: 1

      t.jsonb :exhibit_references, default: []
      t.text :attorney_feedback

      t.timestamps
    end

    add_index :draft_responses, [ :rfe_section_id, :position ]
    add_index :draft_responses, :status
  end
end
