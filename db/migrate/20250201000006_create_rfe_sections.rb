class CreateRfeSections < ActiveRecord::Migration[8.0]
  def change
    create_table :rfe_sections, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :case, type: :uuid, null: false, foreign_key: true
      t.references :rfe_document, type: :uuid, foreign_key: true

      t.integer :position, default: 0, null: false
      t.integer :section_type, default: 0, null: false
      t.string :title
      t.text :original_text
      t.text :summary
      t.string :cfr_reference
      t.float :confidence_score
      t.jsonb :ai_analysis, default: {}

      t.timestamps
    end

    add_index :rfe_sections, [ :case_id, :position ]
    add_index :rfe_sections, :section_type
  end
end
