require "rails_helper"

RSpec.describe SendSlackNotificationJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:integration) { create(:slack_integration, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "#perform" do
    let(:payload_json) { { case_number: "RFE-001", visa_type: "H-1B", petitioner_name: "Acme Corp" }.to_json }
    let(:success_response) { instance_double(Net::HTTPOK) }

    before do
      allow(success_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    it "makes HTTP POST to Slack webhook URL" do
      allow(Net::HTTP).to receive(:post).and_return(success_response)

      described_class.perform_now(integration.id, "case.created", payload_json)

      expect(Net::HTTP).to have_received(:post).with(
        URI(integration.webhook_url),
        anything,
        hash_including("Content-Type" => "application/json")
      )
    end

    it "formats case.created message correctly" do
      allow(Net::HTTP).to receive(:post).and_return(success_response)

      described_class.perform_now(integration.id, "case.created", payload_json)

      expect(Net::HTTP).to have_received(:post) do |_uri, body, _headers|
        parsed = JSON.parse(body)
        expect(parsed["text"]).to include("New RFE Case Created")
        expect(parsed["text"]).to include("RFE-001")
      end
    end

    it "does nothing if integration is not found" do
      expect(Net::HTTP).not_to receive(:post)
      described_class.perform_now(SecureRandom.uuid, "case.created", payload_json)
    end

    it "does nothing if integration is inactive" do
      inactive = create(:slack_integration, :inactive, tenant: tenant, webhook_url: "https://hooks.slack.com/services/T00/B00/yyy")
      expect(Net::HTTP).not_to receive(:post)
      described_class.perform_now(inactive.id, "case.created", payload_json)
    end

    it "raises on non-success response" do
      failure_response = instance_double(Net::HTTPInternalServerError, code: "500", message: "Internal Server Error")
      allow(failure_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(Net::HTTP).to receive(:post).and_return(failure_response)

      job = described_class.new
      expect {
        job.perform(integration.id, "case.created", payload_json)
      }.to raise_error(RuntimeError, /Slack notification failed/)
    end
  end
end
