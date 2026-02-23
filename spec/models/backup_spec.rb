require "rails_helper"

RSpec.describe Backup, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:tenant) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, failed: 3) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at desc" do
        tenant = create(:tenant)
        old_backup = create(:backup, tenant: tenant, created_at: 2.days.ago)
        new_backup = create(:backup, tenant: tenant, created_at: 1.hour.ago)

        expect(Backup.recent.first).to eq(new_backup)
      end
    end
  end

  describe "#file_size_human" do
    let(:backup) { build(:backup) }

    it "returns nil when file_size is nil" do
      backup.file_size = nil
      expect(backup.file_size_human).to be_nil
    end

    it "returns bytes for small files" do
      backup.file_size = 500
      expect(backup.file_size_human).to eq("500 B")
    end

    it "returns KB for medium files" do
      backup.file_size = 7500
      expect(backup.file_size_human).to eq("7.3 KB")
    end

    it "returns MB for large files" do
      backup.file_size = 2_500_000
      expect(backup.file_size_human).to eq("2.4 MB")
    end
  end
end
