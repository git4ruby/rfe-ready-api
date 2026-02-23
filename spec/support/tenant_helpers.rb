module TenantHelpers
  def with_tenant(tenant, &block)
    ActsAsTenant.with_tenant(tenant, &block)
  end

  def set_tenant(tenant)
    ActsAsTenant.current_tenant = tenant
  end
end

RSpec.configure do |config|
  config.after(:each) do
    ActsAsTenant.current_tenant = nil
  end
end
