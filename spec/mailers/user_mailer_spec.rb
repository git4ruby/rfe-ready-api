require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant, first_name: "Alice", last_name: "Johnson") }

  before { ActsAsTenant.current_tenant = tenant }

  describe "#welcome_email" do
    let(:temp_password) { "Temp1234!" }

    it "sends email to the new user" do
      mail = described_class.welcome_email(user, temp_password)

      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("Welcome to RFE Ready")
      expect(mail.subject).to include("Your account is ready")
    end

    it "includes the user first name in body" do
      mail = described_class.welcome_email(user, temp_password)
      body = mail.body.encoded

      expect(body).to include("Alice")
    end

    it "includes the temporary password in body" do
      mail = described_class.welcome_email(user, temp_password)
      body = mail.body.encoded

      expect(body).to include("Temp1234!")
    end

    it "includes the organization name in body" do
      mail = described_class.welcome_email(user, temp_password)
      body = mail.body.encoded

      expect(body).to include(tenant.name)
    end

    it "includes a login URL" do
      mail = described_class.welcome_email(user, temp_password)
      body = mail.body.encoded

      expect(body).to include("/login")
    end

    it "includes the user email in body" do
      mail = described_class.welcome_email(user, temp_password)
      body = mail.body.encoded

      expect(body).to include(user.email)
    end
  end

  describe "from address" do
    it "uses the default from address" do
      mail = described_class.welcome_email(user, "TempPass1!")
      expect(mail.from).to include("noreply@rfeready.com")
    end
  end
end
