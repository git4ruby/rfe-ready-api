class Webhook < ApplicationRecord
  acts_as_tenant :tenant

  SUPPORTED_EVENTS = %w[
    case.created case.updated case.status_changed case.archived
    document.uploaded document.deleted
    draft.approved draft.regenerated
  ].freeze

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid HTTP(S) URL" }
  validates :events, presence: true
  validate :events_must_be_supported

  private

  def events_must_be_supported
    invalid = events - SUPPORTED_EVENTS
    if invalid.any?
      errors.add(:events, "contains unsupported events: #{invalid.join(', ')}")
    end
  end
end
