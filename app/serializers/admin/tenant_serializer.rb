class Admin::TenantSerializer < Blueprinter::Base
  identifier :id
  fields :name, :slug, :plan, :status, :data_retention_days, :created_at, :updated_at

  view :detailed do
    field :settings
    field :encryption_key_id
    field :user_count do |tenant, _options|
      tenant.users.count
    end
    field :case_count do |tenant, _options|
      RfeCase.where(tenant_id: tenant.id).count
    end
  end
end
