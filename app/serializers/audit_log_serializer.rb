class AuditLogSerializer < Blueprinter::Base
  identifier :id

  fields :action, :auditable_type, :auditable_id, :changes_data,
         :ip_address, :user_agent, :created_at

  field :user_name do |log|
    log.user&.full_name
  end

  field :user_email do |log|
    log.user&.email
  end

  field :auditable_name do |log|
    case log.auditable_type
    when "RfeCase"
      log.auditable&.case_number
    when "KnowledgeDoc"
      log.auditable&.title
    when "User"
      log.auditable&.email
    when "DraftResponse"
      "Draft ##{log.auditable&.position}"
    else
      log.auditable_type
    end
  rescue
    log.auditable_type
  end
end
