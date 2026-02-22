class Backup < ApplicationRecord
  belongs_to :tenant
  belongs_to :user, optional: true

  enum :status, { pending: 0, in_progress: 1, completed: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def file_size_human
    return nil unless file_size
    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(1)} KB"
    else
      "#{(file_size / (1024.0 * 1024)).round(1)} MB"
    end
  end
end
