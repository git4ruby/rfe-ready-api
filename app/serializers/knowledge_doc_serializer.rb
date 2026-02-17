class KnowledgeDocSerializer < Blueprinter::Base
  identifier :id
  fields :doc_type, :title, :visa_type, :rfe_category, :is_active, :created_at

  field :uploaded_by_name do |doc|
    doc.uploaded_by&.full_name
  end

  field :file_name do |doc|
    doc.file.attached? ? doc.file.filename.to_s : nil
  end

  field :file_url do |doc|
    if doc.file.attached?
      Rails.application.routes.url_helpers.rails_blob_url(doc.file, host: "http://localhost:3000")
    end
  end

  view :extended do
    field :content
    field :metadata
  end

  view :detail do
    include_view :extended
  end
end
