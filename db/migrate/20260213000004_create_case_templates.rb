class CreateCaseTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :case_templates, id: :uuid do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.string :visa_category, null: false, default: "H-1B"
      t.jsonb :default_sections, default: []
      t.jsonb :default_checklist, default: []
      t.jsonb :default_notes, default: ""
      t.timestamps
    end
    add_index :case_templates, [:tenant_id, :name], unique: true
  end
end
