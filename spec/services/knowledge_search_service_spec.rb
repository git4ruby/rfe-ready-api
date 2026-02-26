require "rails_helper"

RSpec.describe KnowledgeSearchService do
  let(:tenant) { create(:tenant) }

  describe "#call" do
    context "with blank query" do
      it "returns empty results" do
        result = described_class.new(query: "", tenant: tenant).call
        expect(result).to eq({ results: [], query: "" })
      end

      it "returns empty results for nil query" do
        result = described_class.new(query: nil, tenant: tenant).call
        expect(result).to eq({ results: [], query: nil })
      end
    end

    context "with a valid query" do
      let(:knowledge_doc) { create(:knowledge_doc, tenant: tenant, title: "H-1B Guide", doc_type: "regulation") }

      let(:rag_results) do
        [
          {
            content: "Specialty occupation requirements under 8 CFR 214.2(h)",
            metadata: {
              "title" => "H-1B Regulation",
              "doc_type" => "regulation",
              "visa_type" => "H-1B",
              "knowledge_doc_id" => knowledge_doc.id
            },
            distance: 0.15
          },
          {
            content: "Sample evidence for specialty occupation",
            metadata: {
              "title" => "Evidence Checklist",
              "doc_type" => "template",
              "visa_type" => "H-1B",
              "knowledge_doc_id" => nil
            },
            distance: 0.35
          }
        ]
      end

      before do
        rag_service = instance_double(RagRetrievalService)
        allow(RagRetrievalService).to receive(:new).and_return(rag_service)
        allow(rag_service).to receive(:call).and_return(rag_results)
      end

      it "returns formatted results with relevance scores" do
        result = described_class.new(query: "specialty occupation", tenant: tenant).call

        expect(result[:query]).to eq("specialty occupation")
        expect(result[:total]).to eq(2)
        expect(result[:results].size).to eq(2)

        first = result[:results].first
        expect(first[:content]).to eq("Specialty occupation requirements under 8 CFR 214.2(h)")
        expect(first[:relevance_score]).to eq(0.85)
        expect(first[:title]).to eq("H-1B Regulation")
        expect(first[:doc_type]).to eq("regulation")
        expect(first[:visa_type]).to eq("H-1B")
        expect(first[:knowledge_doc_id]).to eq(knowledge_doc.id)
      end

      it "falls back to KnowledgeDoc title when metadata title is missing" do
        rag_results.first[:metadata].delete("title")
        rag_results.first[:metadata].delete("doc_type")

        result = described_class.new(query: "H-1B", tenant: tenant).call

        first = result[:results].first
        expect(first[:title]).to eq("H-1B Guide")
        expect(first[:doc_type]).to eq("regulation")
      end

      it "passes visa_type and limit to RagRetrievalService" do
        described_class.new(query: "test", tenant: tenant, visa_type: "H-1B", limit: 5).call

        expect(RagRetrievalService).to have_received(:new).with(
          query: "test",
          tenant: tenant,
          visa_type: "H-1B",
          limit: 5
        )
      end
    end

    context "when RagRetrievalService returns empty" do
      before do
        rag_service = instance_double(RagRetrievalService)
        allow(RagRetrievalService).to receive(:new).and_return(rag_service)
        allow(rag_service).to receive(:call).and_return([])
      end

      it "returns empty results array" do
        result = described_class.new(query: "nonexistent topic", tenant: tenant).call

        expect(result[:results]).to eq([])
        expect(result[:total]).to eq(0)
        expect(result[:query]).to eq("nonexistent topic")
      end
    end
  end
end
