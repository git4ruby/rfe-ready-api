class RfeDocument < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :case, class_name: "RfeCase"
  belongs_to :uploaded_by, class_name: "User"

  has_one_attached :file

  has_many :rfe_sections, dependent: :nullify
  has_many :exhibits, dependent: :nullify

  enum :document_type, { rfe_notice: 0, supporting_evidence: 1, exhibit: 2 }
  enum :processing_status, { pending: 0, processing: 1, completed: 2, failed: 3 }, prefix: :processing

  validates :filename, presence: true
  validates :document_type, presence: true

  scope :rfe_notices, -> { where(document_type: :rfe_notice) }
  scope :needs_processing, -> { where(processing_status: :pending) }
end
