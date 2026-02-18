class EmbeddingService
  CHUNK_SIZE = 800     # approximate tokens per chunk
  CHUNK_OVERLAP = 200  # overlap between chunks
  MODEL = "text-embedding-3-small"

  attr_reader :knowledge_doc

  def initialize(knowledge_doc)
    @knowledge_doc = knowledge_doc
  end

  def call
    text = extract_text
    return if text.blank?

    chunks = chunk_text(text)
    return if chunks.empty?

    # Delete old embeddings for this doc
    Embedding.where(embeddable: knowledge_doc).destroy_all

    chunks.each_with_index do |chunk, index|
      vector = generate_embedding(chunk)
      next unless vector

      Embedding.create!(
        tenant: knowledge_doc.tenant,
        embeddable: knowledge_doc,
        content: chunk,
        chunk_index: index,
        embedding: vector,
        metadata: {
          doc_type: knowledge_doc.doc_type,
          visa_type: knowledge_doc.visa_type,
          rfe_category: knowledge_doc.rfe_category,
          title: knowledge_doc.title
        }
      )
    end

    Rails.logger.info("EmbeddingService: Generated #{chunks.size} embeddings for KnowledgeDoc #{knowledge_doc.id}")
  end

  private

  def extract_text
    # Prefer text content, fall back to attached file
    if knowledge_doc.content.present?
      knowledge_doc.content
    elsif knowledge_doc.file.attached?
      extract_from_file
    end
  end

  def extract_from_file
    knowledge_doc.file.open do |tempfile|
      content_type = knowledge_doc.file.content_type
      case content_type
      when "application/pdf"
        reader = PDF::Reader.new(tempfile.path)
        reader.pages.map(&:text).join("\n")
      when "text/plain"
        File.read(tempfile.path)
      else
        File.read(tempfile.path)
      end
    end
  rescue => e
    Rails.logger.error("EmbeddingService: Failed to extract text from file for doc #{knowledge_doc.id}: #{e.message}")
    nil
  end

  def chunk_text(text)
    # Split by words, approximate tokens as words * 1.3
    words = text.split
    return [text] if words.size <= CHUNK_SIZE

    chunks = []
    start_idx = 0

    while start_idx < words.size
      end_idx = [start_idx + CHUNK_SIZE, words.size].min
      chunk = words[start_idx...end_idx].join(" ")
      chunks << chunk
      start_idx += (CHUNK_SIZE - CHUNK_OVERLAP)
    end

    chunks
  end

  def generate_embedding(text)
    client = OpenAI::Client.new

    response = client.embeddings(
      parameters: {
        model: MODEL,
        input: text
      }
    )

    response.dig("data", 0, "embedding")
  rescue Faraday::Error => e
    Rails.logger.error("EmbeddingService: OpenAI embedding API error: #{e.message}")
    nil
  end
end
