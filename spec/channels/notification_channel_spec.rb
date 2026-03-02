require "rails_helper"

RSpec.describe NotificationChannel, type: :channel do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }

  before do
    stub_connection current_user: user
    ActsAsTenant.current_tenant = tenant
  end

  it "subscribes and streams for the current user" do
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(user)
  end

  describe ".notify" do
    it "broadcasts a notification to the user" do
      expect {
        described_class.notify(
          user,
          type: "case_assigned",
          title: "New Case Assigned",
          body: "You have been assigned to case RFE-2026-010"
        )
      }.to have_broadcasted_to(user).with(
        hash_including(
          type: "case_assigned",
          title: "New Case Assigned",
          body: "You have been assigned to case RFE-2026-010"
        )
      )
    end

    it "includes optional data payload" do
      expect {
        described_class.notify(
          user,
          type: "comment_added",
          title: "New Comment",
          body: "A comment was added to your case",
          data: { case_id: "abc-123" }
        )
      }.to have_broadcasted_to(user).with(
        hash_including(
          type: "comment_added",
          data: { case_id: "abc-123" }
        )
      )
    end

    it "includes a generated id and timestamp" do
      expect {
        described_class.notify(
          user,
          type: "info",
          title: "Info",
          body: "General notification"
        )
      }.to have_broadcasted_to(user).with(
        hash_including(:id, :created_at)
      )
    end
  end

  context "when no user is connected" do
    it "subscribes but creates an empty stream when current_user is nil" do
      stub_connection current_user: nil
      subscribe
      expect(subscription).to be_confirmed
      expect(subscription.streams).to include("notification:")
    end
  end
end
