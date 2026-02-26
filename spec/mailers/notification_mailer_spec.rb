require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant, first_name: "Jane", last_name: "Doe") }
  let(:attorney) { create(:user, :attorney, tenant: tenant, first_name: "Bob", last_name: "Smith") }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user, case_number: "RFE-2026-001") }

  before { ActsAsTenant.current_tenant = tenant }

  describe "#comment_mention" do
    let(:comment) { create(:comment, case: rfe_case, tenant: tenant, user: attorney, body: "Hey @Jane check this evidence") }

    it "sends email to mentioned user" do
      mail = described_class.comment_mention(user, comment, rfe_case)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("mentioned")
      expect(mail.subject).to include("RFE-2026-001")
    end

    it "includes commenter name and comment body in email" do
      mail = described_class.comment_mention(user, comment, rfe_case)
      body = mail.body.encoded

      expect(body).to include("Bob Smith")
      expect(body).to include("Hey @Jane check this evidence")
    end

    it "includes case URL" do
      mail = described_class.comment_mention(user, comment, rfe_case)
      body = mail.body.encoded

      expect(body).to include("/cases/#{rfe_case.id}")
    end
  end

  describe "#case_status_change" do
    it "sends email about status transition" do
      mail = described_class.case_status_change(user, rfe_case, "draft", "review")

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("status changed")
      expect(mail.subject).to include("review")
    end

    it "includes old and new status in body" do
      mail = described_class.case_status_change(user, rfe_case, "draft", "review")
      body = mail.body.encoded

      expect(body).to include("Draft")
      expect(body).to include("Review")
    end
  end

  describe "#document_uploaded" do
    let(:document) do
      create(:rfe_document,
        case: rfe_case,
        tenant: tenant,
        uploaded_by: attorney,
        filename: "evidence_letter.pdf"
      )
    end

    it "sends email about new document" do
      mail = described_class.document_uploaded(user, document, rfe_case)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("document uploaded")
      expect(mail.subject).to include("RFE-2026-001")
    end

    it "includes uploader name and filename" do
      mail = described_class.document_uploaded(user, document, rfe_case)
      body = mail.body.encoded

      expect(body).to include("Bob Smith")
      expect(body).to include("evidence_letter.pdf")
    end
  end

  describe "#draft_ready" do
    it "sends email about draft readiness" do
      mail = described_class.draft_ready(user, rfe_case)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("Draft responses ready")
      expect(mail.subject).to include("RFE-2026-001")
    end

    it "includes review guidance" do
      mail = described_class.draft_ready(user, rfe_case)
      body = mail.body.encoded

      expect(body).to include("review")
    end
  end

  describe "from address" do
    it "uses the default from address" do
      mail = described_class.draft_ready(user, rfe_case)
      expect(mail.from).to include("noreply@rfeready.com")
    end
  end
end
