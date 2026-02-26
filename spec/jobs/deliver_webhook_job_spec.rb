require "rails_helper"

RSpec.describe DeliverWebhookJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:webhook) { create(:webhook, tenant: tenant, url: "https://example.com/hook", secret: "mysecret") }

  before { ActsAsTenant.current_tenant = tenant }

  describe "#perform" do
    let(:payload_json) { { id: "abc", event: "case.created" }.to_json }
    let(:success_response) { instance_double(Net::HTTPOK, is_a?: true) }

    it "makes HTTP POST with correct headers" do
      allow(Net::HTTP).to receive(:post).and_return(success_response)
      allow(success_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      described_class.perform_now(webhook.id, "case.created", payload_json)

      expect(Net::HTTP).to have_received(:post).with(
        URI("https://example.com/hook"),
        payload_json,
        hash_including(
          "Content-Type" => "application/json",
          "X-Webhook-Event" => "case.created",
          "User-Agent" => "RFEReady-Webhooks/1.0"
        )
      )
    end

    it "includes HMAC signature when secret is present" do
      allow(Net::HTTP).to receive(:post).and_return(success_response)
      allow(success_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      expected_signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'mysecret', payload_json)}"

      described_class.perform_now(webhook.id, "case.created", payload_json)

      expect(Net::HTTP).to have_received(:post).with(
        anything,
        anything,
        hash_including("X-Webhook-Signature" => expected_signature)
      )
    end

    it "sends empty signature when no secret" do
      webhook_no_secret = create(:webhook, :without_secret, tenant: tenant, url: "https://example.com/hook2")
      allow(Net::HTTP).to receive(:post).and_return(success_response)
      allow(success_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      described_class.perform_now(webhook_no_secret.id, "case.created", payload_json)

      expect(Net::HTTP).to have_received(:post).with(
        anything,
        anything,
        hash_including("X-Webhook-Signature" => "")
      )
    end

    it "raises on non-success response" do
      failure_response = instance_double(Net::HTTPInternalServerError, code: "500", message: "Internal Server Error")
      allow(failure_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(Net::HTTP).to receive(:post).and_return(failure_response)

      # perform_now with retry_on catches errors, so test the job instance directly
      job = described_class.new
      expect {
        job.perform(webhook.id, "case.created", payload_json)
      }.to raise_error(RuntimeError, /Webhook delivery failed: 500 Internal Server Error/)
    end

    it "does nothing if webhook is not found" do
      expect(Net::HTTP).not_to receive(:post)

      described_class.perform_now(SecureRandom.uuid, "case.created", payload_json)
    end

    it "does nothing if webhook is inactive" do
      inactive_webhook = create(:webhook, :inactive, tenant: tenant)
      expect(Net::HTTP).not_to receive(:post)

      described_class.perform_now(inactive_webhook.id, "case.created", payload_json)
    end
  end

  describe "queueing" do
    it "enqueues in the webhooks queue" do
      expect {
        described_class.perform_later(webhook.id, "case.created", "{}")
      }.to have_enqueued_job(described_class).on_queue("webhooks")
    end
  end
end
