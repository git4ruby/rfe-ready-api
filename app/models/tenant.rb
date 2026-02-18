class Tenant < ApplicationRecord
  PLATFORM_SLUG = "platform-admin".freeze

  has_many :users, dependent: :destroy
  has_many :rfe_cases, dependent: :destroy
  has_many :knowledge_docs, dependent: :destroy
  has_many :embeddings, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  enum :plan, { trial: 0, basic: 1, professional: 2, enterprise: 3 }
  enum :status, { active: 0, suspended: 1, cancelled: 2 }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }

  before_validation :generate_slug, on: :create

  scope :active, -> { where(status: :active) }
  scope :real_tenants, -> { where.not(slug: PLATFORM_SLUG) }

  def self.platform_tenant
    find_by!(slug: PLATFORM_SLUG)
  end

  def platform_tenant?
    slug == PLATFORM_SLUG
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
