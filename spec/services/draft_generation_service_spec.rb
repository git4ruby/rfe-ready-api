require "rails_helper"

RSpec.describe DraftGenerationService do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, :review, tenant: tenant, created_by: user, visa_type: "H-1B", petitioner_name: "Acme Corp") }

  let(:openai_client) { instance_double(OpenAI::Client) }

  let(:section1) do
    create(:rfe_section,
      tenant: tenant,
      case: rfe_case,
      position: 0,
      title: "Specialty Occupation",
      section_type: :specialty_occupation,
      original_text: "USCIS requires evidence of specialty occupation.",
      summary: "Must prove specialty occupation criteria."
    )
  end

  let(:section2) do
    create(:rfe_section,
      tenant: tenant,
      case: rfe_case,
      position: 1,
      title: "Beneficiary Qualifications",
      section_type: :beneficiary_qualifications,
      original_text: "Evidence of qualifications needed.",
      summary: "Beneficiary must show education meets requirements."
    )
  end

  let(:draft_content) { "Dear USCIS Officer,\n\nWe respectfully submit the following evidence..." }

  let(:openai_chat_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => draft_content
          }
        }
      ]
    }
  end

  before do
    ActsAsTenant.current_tenant = tenant
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(openai_client).to receive(:chat).and_return(openai_chat_response)
    allow(RagRetrievalService).to receive(:new).and_return(
      instance_double(RagRetrievalService, call: [])
    )
  end

  describe "#call" do
    context "happy path with two sections" do
      before do
        section1
        section2
      end

      it "creates DraftResponse records for each section" do
        expect { described_class.new(rfe_case.id).call }.to change { DraftResponse.count }.by(2)
      end

      it "creates drafts with correct attributes for the first section" do
        described_class.new(rfe_case.id).call

        draft = section1.draft_responses.first
        expect(draft).to be_present
        expect(draft.title).to eq("Response: Specialty Occupation")
        expect(draft.ai_generated_content).to eq(draft_content)
        expect(draft.status).to eq("draft")
        expect(draft.version).to eq(1)
        expect(draft.position).to eq(0)
        expect(draft.tenant).to eq(tenant)
        expect(draft.case).to eq(rfe_case)
      end

      it "creates drafts with correct position for the second section" do
        described_class.new(rfe_case.id).call

        draft = section2.draft_responses.first
        expect(draft).to be_present
        expect(draft.position).to eq(1)
        expect(draft.title).to eq("Response: Beneficiary Qualifications")
      end

      it "calls OpenAI for each section" do
        expect(openai_client).to receive(:chat).twice.and_return(openai_chat_response)
        described_class.new(rfe_case.id).call
      end
    end

    context "when sections already have existing drafts" do
      before do
        section1
        section2
        create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section1, position: 0)
      end

      it "skips sections that already have drafts" do
        expect { described_class.new(rfe_case.id).call }.to change { DraftResponse.count }.by(1)
      end

      it "only creates a draft for the section without one" do
        described_class.new(rfe_case.id).call

        expect(section1.draft_responses.count).to eq(1)
        expect(section2.draft_responses.count).to eq(1)
      end
    end

    context "when there are no sections" do
      it "does not create any drafts" do
        expect { described_class.new(rfe_case.id).call }.not_to change { DraftResponse.count }
      end

      it "does not call OpenAI" do
        expect(openai_client).not_to receive(:chat)
        described_class.new(rfe_case.id).call
      end
    end

    context "when OpenAI fails for one section but not the other" do
      before do
        section1
        section2

        call_count = 0
        allow(openai_client).to receive(:chat) do
          call_count += 1
          if call_count == 1
            raise Faraday::ConnectionFailed, "connection refused"
          else
            openai_chat_response
          end
        end
      end

      it "still creates a draft for the successful section" do
        expect { described_class.new(rfe_case.id).call }.to change { DraftResponse.count }.by(1)
      end

      it "does not raise an error" do
        expect { described_class.new(rfe_case.id).call }.not_to raise_error
      end
    end

    context "RAG context integration" do
      let(:rag_results) do
        [
          {
            content: "H-1B specialty occupation requires a bachelor's degree...",
            metadata: { "title" => "H-1B Regulations Guide", "doc_type" => "regulation" },
            distance: 0.15
          },
          {
            content: "Sample response template for specialty occupation RFEs...",
            metadata: { "title" => "SO Response Template", "doc_type" => "template" },
            distance: 0.22
          }
        ]
      end

      before do
        section1

        allow(RagRetrievalService).to receive(:new).and_return(
          instance_double(RagRetrievalService, call: rag_results)
        )
      end

      it "passes RAG context to the OpenAI prompt" do
        expect(openai_client).to receive(:chat) do |args|
          user_message = args[:parameters][:messages].last[:content]
          expect(user_message).to include("RELEVANT KNOWLEDGE BASE CONTEXT")
          expect(user_message).to include("H-1B Regulations Guide")
          expect(user_message).to include("SO Response Template")
          openai_chat_response
        end

        described_class.new(rfe_case.id).call
      end

      it "initializes RagRetrievalService with correct parameters" do
        expect(RagRetrievalService).to receive(:new).with(
          query: a_string_including(section1.title),
          tenant: tenant,
          visa_type: "H-1B",
          limit: 5
        ).and_return(instance_double(RagRetrievalService, call: rag_results))

        described_class.new(rfe_case.id).call
      end
    end

    context "when RAG retrieval fails" do
      before do
        section1

        allow(RagRetrievalService).to receive(:new).and_raise(StandardError, "RAG service down")
      end

      it "still generates the draft without RAG context" do
        expect { described_class.new(rfe_case.id).call }.to change { DraftResponse.count }.by(1)
      end

      it "does not raise an error" do
        expect { described_class.new(rfe_case.id).call }.not_to raise_error
      end
    end
  end

  describe "#regenerate_for_section" do
    before do
      section1
    end

    context "when section has no existing drafts" do
      it "creates a new draft with version 1" do
        service = described_class.new(rfe_case.id)
        draft = service.regenerate_for_section(section1)

        expect(draft).to be_persisted
        expect(draft.version).to eq(1)
        expect(draft.ai_generated_content).to eq(draft_content)
        expect(draft.title).to eq("Response: Specialty Occupation")
        expect(draft.status).to eq("draft")
      end
    end

    context "when section has an existing draft" do
      let!(:existing_draft) do
        create(:draft_response,
          tenant: tenant,
          case: rfe_case,
          rfe_section: section1,
          position: 0,
          version: 1
        )
      end

      it "creates a new draft with incremented version" do
        service = described_class.new(rfe_case.id)

        expect { service.regenerate_for_section(section1) }.to change { DraftResponse.count }.by(1)

        new_draft = section1.draft_responses.order(:version).last
        expect(new_draft.version).to eq(2)
      end

      it "preserves the existing draft" do
        service = described_class.new(rfe_case.id)
        service.regenerate_for_section(section1)

        expect(existing_draft.reload).to be_persisted
      end
    end

    context "when section has multiple existing drafts" do
      before do
        create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section1, position: 0, version: 1)
        create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section1, position: 0, version: 2)
        create(:draft_response, tenant: tenant, case: rfe_case, rfe_section: section1, position: 0, version: 3)
      end

      it "creates a new draft with version 4" do
        service = described_class.new(rfe_case.id)
        draft = service.regenerate_for_section(section1)

        expect(draft.version).to eq(4)
      end
    end

    context "when OpenAI fails" do
      before do
        allow(openai_client).to receive(:chat).and_raise(Faraday::ConnectionFailed, "timeout")
      end

      it "returns nil" do
        service = described_class.new(rfe_case.id)
        result = service.regenerate_for_section(section1)

        expect(result).to be_nil
      end

      it "does not create a draft" do
        service = described_class.new(rfe_case.id)

        expect { service.regenerate_for_section(section1) }.not_to change { DraftResponse.count }
      end
    end
  end
end
