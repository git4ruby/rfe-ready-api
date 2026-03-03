require "rails_helper"

RSpec.describe DraftEditingChannel, type: :channel do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :attorney, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
  let(:section) { create(:rfe_section, case: rfe_case, tenant: tenant) }
  let(:draft) { create(:draft_response, case: rfe_case, rfe_section: section, tenant: tenant) }

  before do
    stub_connection current_user: user
    ActsAsTenant.current_tenant = tenant
  end

  it "subscribes to the draft editing stream" do
    subscribe(draft_response_id: draft.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("draft_editing_#{draft.id}")
  end

  it "broadcasts presence on subscribe" do
    expect {
      subscribe(draft_response_id: draft.id)
    }.to have_broadcasted_to("draft_editing_#{draft.id}").with(hash_including(type: "presence", action: "joined"))
  end
end
