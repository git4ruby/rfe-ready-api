class AddVectorToEmbeddings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    begin
      enable_extension "vector" unless extension_enabled?("vector")
    rescue StandardError => e
      puts "WARNING: pgvector extension not available. Skipping vector column."
      puts "  brew install pgvector"
      return
    end
    add_column :embeddings, :embedding, :vector, limit: 1536
  end

  def down
    remove_column :embeddings, :embedding
  end
end
