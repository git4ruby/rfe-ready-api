class CaseTemplateSerializer < Blueprinter::Base
  identifier :id
  fields :name, :description, :visa_category, :default_sections, :default_checklist, :default_notes, :created_at, :updated_at
end
