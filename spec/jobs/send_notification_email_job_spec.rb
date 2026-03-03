require "rails_helper"

RSpec.describe SendNotificationEmailJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

  before do
    ActsAsTenant.current_tenant = tenant
    ActiveJob::Base.queue_adapter = :test
  end

  describe "#perform" do
    context "comment_mention notification" do
      let(:comment) { create(:comment, case: rfe_case, tenant: tenant, user: attorney) }

      it "sends a comment mention email" do
        expect {
          described_class.new.perform("comment_mention", user.id, tenant.id, { "comment_id" => comment.id })
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "does not send if user disabled comment_mention notifications" do
        user.update!(preferences: { "notifications" => { "comment_mention" => false } })

        expect {
          described_class.new.perform("comment_mention", user.id, tenant.id, { "comment_id" => comment.id })
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "case_status_change notification" do
      it "sends a status change email" do
        expect {
          described_class.new.perform(
            "case_status_change",
            user.id,
            tenant.id,
            { "case_id" => rfe_case.id, "old_status" => "draft", "new_status" => "review" }
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "does not send if user disabled case_status_change notifications" do
        user.update!(preferences: { "notifications" => { "case_status_change" => false } })

        expect {
          described_class.new.perform(
            "case_status_change",
            user.id,
            tenant.id,
            { "case_id" => rfe_case.id, "old_status" => "draft", "new_status" => "review" }
          )
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "document_uploaded notification" do
      let(:document) { create(:rfe_document, case: rfe_case, tenant: tenant, uploaded_by: attorney) }

      it "sends a document uploaded email" do
        expect {
          described_class.new.perform(
            "document_uploaded",
            user.id,
            tenant.id,
            { "document_id" => document.id }
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "draft_ready notification" do
      it "sends a draft ready email" do
        expect {
          described_class.new.perform(
            "draft_ready",
            user.id,
            tenant.id,
            { "case_id" => rfe_case.id }
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "when user is not found" do
      it "discards the job without raising" do
        expect {
          described_class.perform_now("comment_mention", "nonexistent-id", tenant.id, {})
        }.not_to raise_error
      end
    end

    context "default preferences" do
      it "sends email when no notification preferences are set" do
        user.update!(preferences: {})

        expect {
          described_class.new.perform(
            "draft_ready",
            user.id,
            tenant.id,
            { "case_id" => rfe_case.id }
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end
  end

  describe "enqueueing" do
    it "enqueues on the default queue" do
      expect {
        described_class.perform_later("draft_ready", user.id, tenant.id, { "case_id" => rfe_case.id })
      }.to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
