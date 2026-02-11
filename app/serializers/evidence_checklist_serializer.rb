class EvidenceChecklistSerializer < Blueprinter::Base
  identifier :id
  fields :position, :priority, :document_name, :description, :guidance,
         :is_collected, :attorney_notes, :rfe_section_id, :created_at
end
