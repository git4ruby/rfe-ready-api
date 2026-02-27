class DraftResponse < ApplicationRecord
  include Auditable

  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :case, class_name: "RfeCase"
  belongs_to :rfe_section
  belongs_to :locked_by, class_name: "User", optional: true

  enum :status, { draft: 0, editing: 1, reviewed: 2, approved: 3 }, prefix: :response

  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position) }
  scope :approved, -> { where(status: :approved) }
  scope :pending_review, -> { where(status: [ :draft, :editing ]) }

  def approve!(feedback: nil)
    self.attorney_feedback = feedback if feedback
    self.final_content = edited_content.presence || ai_generated_content
    self.status = :approved
    save!
  end
end
