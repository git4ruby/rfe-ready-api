class RfeSectionSerializer < Blueprinter::Base
  identifier :id
  fields :position, :section_type, :title, :summary, :cfr_reference,
         :confidence_score, :created_at

  view :extended do
    field :original_text
    field :ai_analysis
  end

  view :detail do
    include_view :extended
    association :evidence_checklists, blueprint: EvidenceChecklistSerializer
  end
end
