class SlackIntegration < ApplicationRecord
  acts_as_tenant :tenant

  SUPPORTED_EVENTS = %w[
    case.created case.status_changed case.archived
    document.uploaded draft.approved
  ].freeze

  validates :webhook_url, presence: true, format: { with: %r{\Ahttps://hooks\.slack\.com/}, message: "must be a valid Slack webhook URL" }
  validates :events, presence: true
  validate :events_must_be_supported

  private

  def events_must_be_supported
    invalid = events - SUPPORTED_EVENTS
    errors.add(:events, "contains unsupported events: #{invalid.join(', ')}") if invalid.any?
  end
end
