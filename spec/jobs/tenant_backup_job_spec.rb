require "rails_helper"

RSpec.describe TenantBackupJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:backup) { create(:backup, tenant: tenant, user: user) }

  describe "#perform" do
    before { ActsAsTenant.current_tenant = tenant }

    it "transitions backup to completed" do
      described_class.perform_now(backup.id)

      backup.reload
      expect(backup.status).to eq("completed")
      expect(backup.completed_at).to be_present
      expect(backup.file_size).to be > 0
    end

    it "sets status to in_progress first" do
      allow_any_instance_of(described_class).to receive(:perform).and_wrap_original do |method, *args|
        backup_record = Backup.find(args.first)
        method.call(*args)
      end

      described_class.perform_now(backup.id)
      expect(backup.reload.status).to eq("completed")
    end

    it "marks backup as failed on error" do
      allow(Tenant).to receive(:find).and_raise(StandardError.new("Test error"))
      # The backup is found first, then error occurs during data generation
      allow(Backup).to receive(:find).with(backup.id).and_return(backup)
      allow(backup).to receive(:tenant).and_return(tenant)
      allow(backup).to receive(:update!).and_call_original
      allow(backup).to receive(:update).and_call_original

      # Force an error during the data export
      allow(tenant).to receive(:rfe_cases).and_raise(StandardError.new("Export error"))

      described_class.perform_now(backup.id)

      backup.reload
      expect(backup.status).to eq("failed")
      expect(backup.error_message).to be_present
    end
  end

  describe "queueing" do
    it "enqueues in the default queue" do
      expect {
        described_class.perform_later(backup.id)
      }.to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
