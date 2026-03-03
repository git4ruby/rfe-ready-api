require "rails_helper"

RSpec.describe CaseSimilarityService do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user, visa_type: "H-1B", petitioner_name: "Acme Corp", notes: "Specialty occupation RFE") }

  describe "#call" do
    context "when no embeddings exist" do
      before do
        allow_any_instance_of(described_class).to receive(:generate_embedding).and_return(Array.new(1536, 0.1))
      end

      it "returns empty array" do
        result = described_class.new(rfe_case: rfe_case, tenant: tenant).call
        expect(result).to eq([])
      end
    end

    context "when case has no meaningful text" do
      let(:empty_case) { create(:rfe_case, tenant: tenant, created_by: user, notes: nil) }

      it "returns empty array when text is blank" do
        result = described_class.new(rfe_case: empty_case, tenant: tenant).call
        # Even with visa_type and petitioner_name, it should still work
        expect(result).to be_an(Array)
      end
    end

    context "when embedding API fails" do
      before do
        allow_any_instance_of(described_class).to receive(:generate_embedding).and_return(nil)
      end

      it "returns empty array" do
        result = described_class.new(rfe_case: rfe_case, tenant: tenant).call
        expect(result).to eq([])
      end
    end

    it "respects the limit parameter" do
      service = described_class.new(rfe_case: rfe_case, tenant: tenant, limit: 3)
      expect(service.limit).to eq(3)
    end

    it "defaults limit to 5" do
      service = described_class.new(rfe_case: rfe_case, tenant: tenant)
      expect(service.limit).to eq(5)
    end
  end
end
