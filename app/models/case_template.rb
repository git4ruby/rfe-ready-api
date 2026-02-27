class CaseTemplate < ApplicationRecord
  acts_as_tenant :tenant

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :visa_category, presence: true
  validates :default_sections, presence: true
  validates :default_checklist, presence: true
end
