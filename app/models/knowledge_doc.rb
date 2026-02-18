class KnowledgeDoc < ApplicationRecord
  include Auditable

  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :uploaded_by, class_name: "User"

  has_one_attached :file
  has_many :embeddings, as: :embeddable, dependent: :destroy

  enum :doc_type, { template: 0, sample_response: 1, regulation: 2, firm_knowledge: 3 }

  validates :title, presence: true
  validates :doc_type, presence: true

  scope :active, -> { where(is_active: true) }
  scope :for_visa, ->(visa) { where(visa_type: visa) }
  scope :for_category, ->(cat) { where(rfe_category: cat) }
  scope :search, ->(q) { where("title ILIKE :q OR content ILIKE :q", q: "%#{sanitize_sql_like(q)}%") }
end
