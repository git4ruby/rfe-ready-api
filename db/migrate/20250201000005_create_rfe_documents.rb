class CreateRfeDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :rfe_documents, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :case, type: :uuid, null: false, foreign_key: true
      t.references :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }

      t.integer :document_type, default: 0, null: false
      t.string :filename, null: false
      t.string :content_type
      t.bigint :file_size
      t.string :s3_key

      t.text :extracted_text
      t.text :ocr_text
      t.integer :processing_status, default: 0, null: false
      t.jsonb :processing_metadata, default: {}

      t.timestamps
    end

    add_index :rfe_documents, [ :case_id, :document_type ]
    add_index :rfe_documents, :processing_status
  end
end
