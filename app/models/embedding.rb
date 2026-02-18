class Embedding < ApplicationRecord
  acts_as_tenant :tenant
  has_neighbors :embedding

  belongs_to :tenant
  belongs_to :embeddable, polymorphic: true

  validates :content, presence: true

  scope :for_type, ->(type) { where(embeddable_type: type) }
end
