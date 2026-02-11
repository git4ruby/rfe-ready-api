class DraftResponseSerializer < Blueprinter::Base
  identifier :id
  fields :position, :title, :status, :version, :rfe_section_id,
         :ai_generated_content, :edited_content, :final_content,
         :attorney_feedback, :created_at, :updated_at

  view :detail do
    field :exhibit_references
  end
end
