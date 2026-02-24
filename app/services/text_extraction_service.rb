class TextExtractionService
  attr_reader :document

  def initialize(document)
    @document = document
  end

  def call
    return nil unless document.file.attached?

    text = extract_text
    document.update!(extracted_text: text, processing_status: :completed)
    text
  rescue => e
    document.update!(
      processing_status: :failed,
      processing_metadata: { error: e.message, failed_at: Time.current }
    )
    raise
  end

  private

  def extract_text
    content_type = document.file.content_type

    case content_type
    when "text/plain"
      extract_plain_text
    when "application/pdf"
      extract_pdf_text
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      extract_docx_text
    else
      extract_plain_text
    end
  end

  def extract_plain_text
    document.file.download.force_encoding("UTF-8")
  end

  def extract_pdf_text
    tempfile = Tempfile.new([ "rfe_doc", ".pdf" ])
    begin
      tempfile.binmode
      tempfile.write(document.file.download)
      tempfile.rewind

      reader = PDF::Reader.new(tempfile.path)
      reader.pages.map(&:text).join("\n\n")
    rescue PDF::Reader::MalformedPDFError => e
      Rails.logger.warn("Malformed PDF for document #{document.id}, falling back to plain text: #{e.message}")
      extract_plain_text
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  def extract_docx_text
    # Basic DOCX extraction — reads the XML content
    tempfile = Tempfile.new([ "rfe_doc", ".docx" ])
    begin
      tempfile.binmode
      tempfile.write(document.file.download)
      tempfile.rewind

      Zip::File.open(tempfile.path) do |zip|
        entry = zip.find_entry("word/document.xml")
        return "" unless entry

        xml = entry.get_input_stream.read
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        doc.xpath("//p").map { |p| p.text.strip }.reject(&:blank?).join("\n")
      end
    ensure
      tempfile.close
      tempfile.unlink
    end
  rescue => e
    Rails.logger.warn("DOCX extraction failed, falling back to plain text: #{e.message}")
    extract_plain_text
  end
end
