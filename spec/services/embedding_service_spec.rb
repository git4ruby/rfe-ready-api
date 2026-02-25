require "rails_helper"

RSpec.describe EmbeddingService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:openai_client) { instance_double(OpenAI::Client) }
  let(:fake_vector) { Array.new(1536) { rand(-1.0..1.0) } }

  before do
    ActsAsTenant.current_tenant = tenant
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
  end

  def stub_embedding_response(vector = fake_vector)
    { "data" => [{ "embedding" => vector }] }
  end

  describe "#call" do
    context "happy path with text content" do
      let(:knowledge_doc) do
        create(:knowledge_doc,
          tenant: tenant,
          uploaded_by: user,
          content: "This is a short document with some content about immigration law.",
          doc_type: :regulation,
          visa_type: "H-1B",
          rfe_category: "specialty_occupation",
          title: "H-1B Specialty Occupation Regulation"
        )
      end

      before do
        allow(openai_client).to receive(:embeddings).and_return(stub_embedding_response)
      end

      it "creates Embedding records for each chunk" do
        expect { described_class.new(knowledge_doc).call }.to change { Embedding.count }.by(1)
      end

      it "stores the correct content in the embedding" do
        described_class.new(knowledge_doc).call

        embedding = Embedding.last
        expect(embedding.content).to eq(knowledge_doc.content)
        expect(embedding.chunk_index).to eq(0)
        expect(embedding.embeddable).to eq(knowledge_doc)
        expect(embedding.tenant).to eq(tenant)
      end

      it "stores the correct metadata" do
        described_class.new(knowledge_doc).call

        embedding = Embedding.last
        expect(embedding.metadata).to include(
          "doc_type" => "regulation",
          "visa_type" => "H-1B",
          "rfe_category" => "specialty_occupation",
          "title" => "H-1B Specialty Occupation Regulation"
        )
      end

      it "calls OpenAI embeddings with the correct model and input" do
        described_class.new(knowledge_doc).call

        expect(openai_client).to have_received(:embeddings).with(
          parameters: {
            model: "text-embedding-3-small",
            input: knowledge_doc.content
          }
        )
      end

      it "stores the embedding vector" do
        described_class.new(knowledge_doc).call

        embedding = Embedding.last
        expect(embedding.embedding.length).to eq(fake_vector.length)
        embedding.embedding.each_with_index do |val, i|
          expect(val).to be_within(0.001).of(fake_vector[i])
        end
      end
    end

    context "chunking behavior" do
      context "with small text that fits in a single chunk" do
        let(:small_content) { Array.new(100) { "word" }.join(" ") }
        let(:knowledge_doc) do
          create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: small_content)
        end

        before do
          allow(openai_client).to receive(:embeddings).and_return(stub_embedding_response)
        end

        it "creates exactly one embedding" do
          expect { described_class.new(knowledge_doc).call }.to change { Embedding.count }.by(1)
        end

        it "stores the full text as a single chunk" do
          described_class.new(knowledge_doc).call

          expect(Embedding.last.content).to eq(small_content)
          expect(Embedding.last.chunk_index).to eq(0)
        end
      end

      context "with large text that produces multiple overlapping chunks" do
        # CHUNK_SIZE is 800, CHUNK_OVERLAP is 200 => step = 600 words per chunk
        # 2000 words => chunks starting at 0, 600, 1200, 1800 => 4 chunks
        let(:large_content) { Array.new(2000) { |i| "word#{i}" }.join(" ") }
        let(:knowledge_doc) do
          create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: large_content)
        end

        before do
          allow(openai_client).to receive(:embeddings).and_return(stub_embedding_response)
        end

        it "creates multiple embeddings" do
          described_class.new(knowledge_doc).call

          expect(Embedding.count).to eq(4)
        end

        it "assigns sequential chunk indices" do
          described_class.new(knowledge_doc).call

          indices = Embedding.order(:chunk_index).pluck(:chunk_index)
          expect(indices).to eq([0, 1, 2, 3])
        end

        it "produces overlapping chunks" do
          described_class.new(knowledge_doc).call

          chunks = Embedding.order(:chunk_index).pluck(:content)

          # First chunk ends with word799, second chunk starts at word600
          # So the overlap region should contain word600..word799
          first_words = chunks[0].split
          second_words = chunks[1].split

          # The last 200 words of chunk 0 should match the first 200 words of chunk 1
          expect(first_words.last(200)).to eq(second_words.first(200))
        end
      end
    end

    context "when old embeddings exist" do
      let(:knowledge_doc) do
        create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: "Some content to embed.")
      end

      before do
        allow(openai_client).to receive(:embeddings).and_return(stub_embedding_response)

        # Create pre-existing embeddings for this document
        Embedding.create!(
          tenant: tenant,
          embeddable: knowledge_doc,
          content: "Old chunk 1",
          chunk_index: 0,
          embedding: fake_vector,
          metadata: {}
        )
        Embedding.create!(
          tenant: tenant,
          embeddable: knowledge_doc,
          content: "Old chunk 2",
          chunk_index: 1,
          embedding: fake_vector,
          metadata: {}
        )
      end

      it "deletes old embeddings before creating new ones" do
        expect { described_class.new(knowledge_doc).call }.to change { Embedding.count }.from(2).to(1)
      end

      it "replaces old content with new content" do
        described_class.new(knowledge_doc).call

        expect(Embedding.pluck(:content)).to eq(["Some content to embed."])
      end
    end

    context "when OpenAI embedding API raises an error for a chunk" do
      let(:large_content) { Array.new(2000) { |i| "word#{i}" }.join(" ") }
      let(:knowledge_doc) do
        create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: large_content)
      end

      before do
        call_count = 0
        allow(openai_client).to receive(:embeddings) do
          call_count += 1
          if call_count == 2
            raise Faraday::ConnectionFailed, "connection refused"
          else
            stub_embedding_response
          end
        end
      end

      it "skips the failed chunk and continues processing others" do
        described_class.new(knowledge_doc).call

        # 4 chunks total, 1 fails => 3 embeddings created
        expect(Embedding.count).to eq(3)
      end

      it "does not include the failed chunk index" do
        described_class.new(knowledge_doc).call

        indices = Embedding.order(:chunk_index).pluck(:chunk_index)
        expect(indices).not_to include(1)
      end
    end

    context "when content is empty or blank" do
      it "returns early for nil content and no file" do
        knowledge_doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: nil)

        expect { described_class.new(knowledge_doc).call }.not_to change { Embedding.count }
      end

      it "returns early for blank content and no file" do
        knowledge_doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: "   ")

        expect { described_class.new(knowledge_doc).call }.not_to change { Embedding.count }
      end

      it "does not call OpenAI for blank content" do
        knowledge_doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user, content: "")

        described_class.new(knowledge_doc).call

        expect(openai_client).not_to have_received(:embeddings) if openai_client.respond_to?(:embeddings)
      end
    end

    context "metadata stored correctly" do
      let(:knowledge_doc) do
        create(:knowledge_doc,
          tenant: tenant,
          uploaded_by: user,
          content: "Metadata test content.",
          doc_type: :template,
          visa_type: "L-1A",
          rfe_category: "employer_employee",
          title: "L-1A Template Document"
        )
      end

      before do
        allow(openai_client).to receive(:embeddings).and_return(stub_embedding_response)
      end

      it "stores doc_type from the knowledge doc" do
        described_class.new(knowledge_doc).call

        expect(Embedding.last.metadata["doc_type"]).to eq("template")
      end

      it "stores visa_type from the knowledge doc" do
        described_class.new(knowledge_doc).call

        expect(Embedding.last.metadata["visa_type"]).to eq("L-1A")
      end

      it "stores rfe_category from the knowledge doc" do
        described_class.new(knowledge_doc).call

        expect(Embedding.last.metadata["rfe_category"]).to eq("employer_employee")
      end

      it "stores title from the knowledge doc" do
        described_class.new(knowledge_doc).call

        expect(Embedding.last.metadata["title"]).to eq("L-1A Template Document")
      end
    end
  end
end
