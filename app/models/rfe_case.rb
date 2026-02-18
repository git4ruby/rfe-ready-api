class RfeCase < ApplicationRecord
  include AASM
  include Auditable

  self.table_name = "cases"

  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :created_by, class_name: "User"
  belongs_to :assigned_attorney, class_name: "User", optional: true

  has_many :rfe_documents, foreign_key: :case_id, dependent: :destroy
  has_many :rfe_sections, foreign_key: :case_id, dependent: :destroy
  has_many :evidence_checklists, foreign_key: :case_id, dependent: :destroy
  has_many :draft_responses, foreign_key: :case_id, dependent: :destroy
  has_many :exhibits, foreign_key: :case_id, dependent: :destroy

  # Lockbox encryption for PII
  has_encrypted :beneficiary_name
  blind_index :beneficiary_name

  validates :case_number, presence: true, uniqueness: { scope: :tenant_id }
  validates :visa_type, presence: true
  validates :petitioner_name, presence: true

  scope :active, -> { where.not(status: "archived") }
  scope :approaching_deadline, -> {
    where("rfe_deadline <= ? AND status != ?", 14.days.from_now, "archived")
      .order(:rfe_deadline)
  }

  aasm column: :status do
    state :draft, initial: true
    state :analyzing
    state :review
    state :responded
    state :archived

    event :start_analysis do
      transitions from: :draft, to: :analyzing
    end

    event :complete_analysis do
      transitions from: :analyzing, to: :review
    end

    event :mark_responded do
      transitions from: :review, to: :responded
    end

    event :archive do
      transitions from: [:draft, :review, :responded], to: :archived
    end

    event :reopen do
      transitions from: :archived, to: :draft
    end
  end
end
