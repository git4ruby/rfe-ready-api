class AddVectorToEmbeddings < ActiveRecord::Migration[8.0]
  def up
    enable_extension "vector" unless extension_enabled?("vector")
    add_column :embeddings, :embedding, :vector, limit: 1536
  end

  def down
    remove_column :embeddings, :embedding
  end
end
