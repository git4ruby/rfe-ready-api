require "rails_helper"

RSpec.describe CaseUpdatesChannel, type: :channel do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }

  before do
    stub_connection current_user: user
    ActsAsTenant.current_tenant = tenant
  end

  it "subscribes to the tenant case updates stream" do
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("case_updates_tenant_#{tenant.id}")
  end

  it "streams from the correct tenant-scoped channel" do
    subscribe
    expect(subscription).to have_stream_from("case_updates_tenant_#{user.tenant_id}")
  end

  describe ".broadcast_update" do
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

    it "broadcasts a case update to the tenant stream" do
      expect {
        described_class.broadcast_update(
          tenant.id,
          type: "status_change",
          case_id: rfe_case.id,
          case_number: rfe_case.case_number,
          message: "Case status changed to review"
        )
      }.to have_broadcasted_to("case_updates_tenant_#{tenant.id}").with(
        hash_including(
          type: "status_change",
          case_id: rfe_case.id,
          case_number: rfe_case.case_number,
          message: "Case status changed to review"
        )
      )
    end

    it "includes a generated id and timestamp" do
      expect {
        described_class.broadcast_update(
          tenant.id,
          type: "new_case",
          case_id: rfe_case.id,
          case_number: rfe_case.case_number,
          message: "New case created"
        )
      }.to have_broadcasted_to("case_updates_tenant_#{tenant.id}").with(
        hash_including(:id, :created_at)
      )
    end
  end

  context "when no user is connected" do
    it "raises an error when subscribing without a current_user" do
      stub_connection current_user: nil
      expect { subscribe }.to raise_error(NoMethodError, /undefined method `tenant_id' for nil/)
    end
  end
end
