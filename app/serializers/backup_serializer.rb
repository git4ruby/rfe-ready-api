class BackupSerializer < Blueprinter::Base
  identifier :id
  fields :status, :file_url, :file_size, :error_message, :completed_at, :created_at

  field :file_size_human
  field :user_name do |backup|
    backup.user&.full_name || "System"
  end
end
