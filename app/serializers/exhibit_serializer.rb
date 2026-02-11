class ExhibitSerializer < Blueprinter::Base
  identifier :id
  fields :label, :title, :description, :position, :page_range,
         :rfe_document_id, :created_at

  field :document_filename do |exhibit|
    exhibit.rfe_document&.filename
  end
end
