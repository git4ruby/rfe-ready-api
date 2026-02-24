class CreateKnowledgeDocs < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_docs, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }

      t.integer :doc_type, default: 0, null: false
      t.string :title, null: false
      t.text :content
      t.string :visa_type
      t.string :rfe_category
      t.jsonb :metadata, default: {}
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :knowledge_docs, [ :tenant_id, :doc_type ]
    add_index :knowledge_docs, [ :visa_type, :rfe_category ]
  end
end
