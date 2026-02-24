class CreateEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :embeddings, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.string :embeddable_type, null: false
      t.uuid :embeddable_id, null: false

      t.text :content
      t.integer :chunk_index, default: 0
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :embeddings, [ :embeddable_type, :embeddable_id ]

    # Add vector column if pgvector is available
    if extension_enabled?("vector")
      add_column :embeddings, :embedding, :vector, limit: 1536
    end
  end

  private

  def extension_enabled?(name)
    query = "SELECT 1 FROM pg_extension WHERE extname = '#{name}'"
    ActiveRecord::Base.connection.select_value(query).present?
  rescue
    false
  end
end
