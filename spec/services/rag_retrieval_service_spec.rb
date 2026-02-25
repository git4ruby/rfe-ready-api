require "rails_helper"

RSpec.describe RagRetrievalService do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }

  let(:openai_client) { instance_double(OpenAI::Client) }
  let(:query_embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  let(:openai_embedding_response) do
    {
      "data" => [
        { "embedding" => query_embedding }
      ]
    }
  end

  let(:knowledge_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, visa_type: "H-1B", rfe_category: "specialty_occupation") }

  before do
    ActsAsTenant.current_tenant = tenant
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(openai_client).to receive(:embeddings).and_return(openai_embedding_response)
  end

  describe "#call" do
    context "happy path" do
      let!(:embedding1) do
        Embedding.create!(
          tenant: tenant,
          embeddable: knowledge_doc,
          content: "H-1B specialty occupation requirements under 8 CFR 214.2",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: { "title" => "H-1B Guide", "doc_type" => "regulation", "visa_type" => "H-1B" }
        )
      end

      it "returns results with content, metadata, and distance" do
        service = described_class.new(query: "specialty occupation requirements", tenant: tenant)
        results = service.call

        expect(results).to be_an(Array)
        expect(results).not_to be_empty

        first_result = results.first
        expect(first_result).to have_key(:content)
        expect(first_result).to have_key(:metadata)
        expect(first_result).to have_key(:distance)
      end

      it "calls OpenAI embeddings API with the correct model" do
        expect(openai_client).to receive(:embeddings).with(
          parameters: {
            model: "text-embedding-3-small",
            input: "specialty occupation requirements"
          }
        ).and_return(openai_embedding_response)

        described_class.new(query: "specialty occupation requirements", tenant: tenant).call
      end

      it "returns content from matching embeddings" do
        service = described_class.new(query: "specialty occupation requirements", tenant: tenant)
        results = service.call

        expect(results.first[:content]).to eq("H-1B specialty occupation requirements under 8 CFR 214.2")
      end
    end

    context "when query is blank" do
      it "returns an empty array for nil query" do
        service = described_class.new(query: nil, tenant: tenant)
        expect(service.call).to eq([])
      end

      it "returns an empty array for empty string query" do
        service = described_class.new(query: "", tenant: tenant)
        expect(service.call).to eq([])
      end

      it "returns an empty array for whitespace-only query" do
        service = described_class.new(query: "   ", tenant: tenant)
        expect(service.call).to eq([])
      end

      it "does not call OpenAI" do
        expect(openai_client).not_to receive(:embeddings)
        described_class.new(query: "", tenant: tenant).call
      end
    end

    context "when OpenAI embedding API raises an error" do
      before do
        allow(openai_client).to receive(:embeddings).and_raise(Faraday::ConnectionFailed, "connection refused")
      end

      it "returns an empty array" do
        service = described_class.new(query: "test query", tenant: tenant)
        expect(service.call).to eq([])
      end

      it "does not raise an error" do
        service = described_class.new(query: "test query", tenant: tenant)
        expect { service.call }.not_to raise_error
      end
    end

    context "visa type filtering" do
      let(:h1b_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, visa_type: "H-1B") }
      let(:l1_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, visa_type: "L-1") }
      let(:general_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, visa_type: nil) }

      let!(:h1b_embedding) do
        Embedding.create!(
          tenant: tenant,
          embeddable: h1b_doc,
          content: "H-1B specific content",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: { "visa_type" => "H-1B" }
        )
      end

      let!(:l1_embedding) do
        Embedding.create!(
          tenant: tenant,
          embeddable: l1_doc,
          content: "L-1 specific content",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: { "visa_type" => "L-1" }
        )
      end

      let!(:general_embedding) do
        Embedding.create!(
          tenant: tenant,
          embeddable: general_doc,
          content: "General immigration content",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: {}
        )
      end

      it "filters results by visa type and includes docs with no visa type" do
        service = described_class.new(query: "immigration", tenant: tenant, visa_type: "H-1B")
        results = service.call

        result_contents = results.map { |r| r[:content] }
        expect(result_contents).to include("H-1B specific content")
        expect(result_contents).to include("General immigration content")
        expect(result_contents).not_to include("L-1 specific content")
      end
    end

    context "RFE category filtering" do
      let(:so_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, rfe_category: "specialty_occupation") }
      let(:ee_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, rfe_category: "employer_employee") }
      let(:general_doc) { create(:knowledge_doc, tenant: tenant, uploaded_by: user, rfe_category: nil) }

      let!(:so_embedding) do
        Embedding.create!(
          tenant: tenant,
          embeddable: so_doc,
          content: "Specialty occupation analysis",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: { "rfe_category" => "specialty_occupation" }
        )
      end

      let!(:ee_embedding) do
        Embedding.create!(
          tenant: tenant,
          embeddable: ee_doc,
          content: "Employer-employee relationship",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: { "rfe_category" => "employer_employee" }
        )
      end

      let!(:general_embedding) do
        Embedding.create!(
          tenant: tenant,
          embeddable: general_doc,
          content: "General RFE guidance",
          embedding: Array.new(1536) { rand(-1.0..1.0) },
          metadata: {}
        )
      end

      it "filters results by RFE category and includes docs with no category" do
        service = described_class.new(
          query: "occupation analysis",
          tenant: tenant,
          rfe_category: "specialty_occupation"
        )
        results = service.call

        result_contents = results.map { |r| r[:content] }
        expect(result_contents).to include("Specialty occupation analysis")
        expect(result_contents).to include("General RFE guidance")
        expect(result_contents).not_to include("Employer-employee relationship")
      end
    end

    context "limit parameter" do
      let(:docs) do
        Array.new(8) { create(:knowledge_doc, tenant: tenant, uploaded_by: user) }
      end

      before do
        docs.each_with_index do |doc, i|
          Embedding.create!(
            tenant: tenant,
            embeddable: doc,
            content: "Document content #{i}",
            embedding: Array.new(1536) { rand(-1.0..1.0) },
            metadata: {}
          )
        end
      end

      it "defaults to 5 results" do
        service = described_class.new(query: "document content", tenant: tenant)
        results = service.call

        expect(results.length).to be <= 5
      end

      it "respects a custom limit" do
        service = described_class.new(query: "document content", tenant: tenant, limit: 3)
        results = service.call

        expect(results.length).to be <= 3
      end

      it "returns all results if limit exceeds available embeddings" do
        service = described_class.new(query: "document content", tenant: tenant, limit: 20)
        results = service.call

        expect(results.length).to eq(8)
      end
    end

    context "when there are no matching embeddings" do
      it "returns an empty array" do
        service = described_class.new(query: "something with no matches", tenant: tenant)
        results = service.call

        expect(results).to eq([])
      end
    end

    context "when OpenAI returns nil embedding" do
      before do
        allow(openai_client).to receive(:embeddings).and_return(
          { "data" => [{ "embedding" => nil }] }
        )
      end

      it "returns an empty array" do
        service = described_class.new(query: "test query", tenant: tenant)
        expect(service.call).to eq([])
      end
    end

    context "text truncation" do
      it "truncates long queries to 8000 characters" do
        long_query = "a" * 10_000

        expect(openai_client).to receive(:embeddings) do |args|
          expect(args[:parameters][:model]).to eq("text-embedding-3-small")
          expect(args[:parameters][:input].length).to be <= 8000
        end.and_return(openai_embedding_response)

        described_class.new(query: long_query, tenant: tenant).call
      end
    end
  end
end
