class KnowledgeDoc < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :uploaded_by, class_name: "User"

  has_one_attached :file

  enum :doc_type, { template: 0, sample_response: 1, regulation: 2, firm_knowledge: 3 }

  validates :title, presence: true
  validates :doc_type, presence: true

  scope :active, -> { where(is_active: true) }
  scope :for_visa, ->(visa) { where(visa_type: visa) }
  scope :for_category, ->(cat) { where(rfe_category: cat) }
end
