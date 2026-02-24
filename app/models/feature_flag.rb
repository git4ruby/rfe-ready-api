class FeatureFlag < ApplicationRecord
  belongs_to :tenant

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :for_tenant, ->(tenant) { where(tenant: tenant) }

  def self.enabled?(name, user)
    flag = where(tenant: user.tenant, name: name).first
    return false unless flag&.enabled?

    # Check role restriction
    if flag.allowed_roles.present?
      return false unless flag.allowed_roles.include?(user.role)
    end

    # Check plan restriction
    if flag.allowed_plans.present?
      return false unless flag.allowed_plans.include?(user.tenant.plan)
    end

    true
  end

  def self.seed_defaults(tenant)
    defaults = [
      { name: "ai_analysis", enabled: true, allowed_roles: [], allowed_plans: [] },
      { name: "bulk_actions", enabled: true, allowed_roles: %w[admin], allowed_plans: [] },
      { name: "export_pdf", enabled: true, allowed_roles: %w[admin attorney], allowed_plans: [] },
      { name: "knowledge_base", enabled: true, allowed_roles: [], allowed_plans: [] },
      { name: "draft_generation", enabled: true, allowed_roles: %w[admin attorney], allowed_plans: [] },
      { name: "audit_log_export", enabled: true, allowed_roles: %w[admin], allowed_plans: %w[professional enterprise] }
    ]

    defaults.each do |attrs|
      find_or_create_by!(tenant: tenant, name: attrs[:name]) do |flag|
        flag.enabled = attrs[:enabled]
        flag.allowed_roles = attrs[:allowed_roles]
        flag.allowed_plans = attrs[:allowed_plans]
      end
    end
  end
end
