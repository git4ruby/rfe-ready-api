class RfeDocumentSerializer < Blueprinter::Base
  identifier :id
  fields :document_type, :filename, :content_type, :file_size,
         :processing_status, :created_at

  field :uploaded_by_name do |doc|
    doc.uploaded_by&.full_name
  end

  field :file_url do |doc|
    if doc.file.attached?
      Rails.application.routes.url_helpers.rails_blob_url(
        doc.file,
        host: ENV.fetch("APP_HOST", "http://localhost:3000")
      )
    end
  end

  view :extended do
    field :extracted_text
    field :ocr_text
    field :processing_metadata
  end
end
