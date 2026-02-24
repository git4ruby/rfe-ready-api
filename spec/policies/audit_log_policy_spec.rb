require "rails_helper"

RSpec.describe AuditLogPolicy, type: :policy do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:paralegal) { create(:user, :paralegal, tenant: tenant) }
  let(:viewer) { create(:user, :viewer, tenant: tenant) }

  subject { described_class }

  permissions :index? do
    it "permits admin" do
      expect(subject).to permit(admin, AuditLog)
    end

    it "denies non-admin roles" do
      [ attorney, paralegal, viewer ].each do |user|
        expect(subject).not_to permit(user, AuditLog)
      end
    end
  end
end
