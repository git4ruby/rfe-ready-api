require "rails_helper"

RSpec.describe RfeAnalysisService do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, :analyzing, tenant: tenant, created_by: user) }
  let!(:rfe_document) { create(:rfe_document, :rfe_notice, tenant: tenant, case: rfe_case, uploaded_by: user) }

  let(:openai_client) { instance_double(OpenAI::Client) }

  let(:valid_analysis_response) do
    {
      "sections" => [
        {
          "title" => "Specialty Occupation Issue",
          "section_type" => "specialty_occupation",
          "original_text" => "USCIS requires evidence that the position qualifies as a specialty occupation.",
          "summary" => "The petitioner must demonstrate the position meets specialty occupation criteria.",
          "cfr_reference" => "8 CFR 214.2(h)(4)(ii)",
          "confidence_score" => 0.92,
          "evidence_needed" => [
            {
              "document_name" => "Expert Opinion Letter",
              "description" => "Letter from industry expert confirming specialty nature",
              "guidance" => "Should reference specific degree requirements",
              "priority" => "required"
            },
            {
              "document_name" => "Job Postings Comparison",
              "description" => "Similar job postings requiring specialized degrees",
              "guidance" => "Include at least 5 comparable postings",
              "priority" => "recommended"
            }
          ]
        },
        {
          "title" => "Beneficiary Qualifications",
          "section_type" => "beneficiary_qualifications",
          "original_text" => "Evidence that the beneficiary possesses the required qualifications.",
          "summary" => "USCIS needs proof the beneficiary has the necessary education and experience.",
          "cfr_reference" => "8 CFR 214.2(h)(4)(iii)(C)",
          "confidence_score" => 0.88,
          "evidence_needed" => [
            {
              "document_name" => "Credential Evaluation",
              "description" => "Evaluation of foreign degree equivalency",
              "guidance" => "Must be from a NACES-member evaluator",
              "priority" => "required"
            }
          ]
        }
      ]
    }
  end

  let(:openai_chat_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => valid_analysis_response.to_json
          }
        }
      ]
    }
  end

  before do
    ActsAsTenant.current_tenant = tenant
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(TextExtractionService).to receive(:new).and_return(
      instance_double(TextExtractionService, call: "Sample RFE notice text content for analysis.")
    )
  end

  describe "#call" do
    context "happy path" do
      before do
        allow(openai_client).to receive(:chat).and_return(openai_chat_response)
      end

      it "creates RfeSection records from the analysis" do
        expect { described_class.new(rfe_case.id).call }.to change { RfeSection.count }.by(2)
      end

      it "creates EvidenceChecklist records from the analysis" do
        expect { described_class.new(rfe_case.id).call }.to change { EvidenceChecklist.count }.by(3)
      end

      it "creates sections with correct attributes" do
        described_class.new(rfe_case.id).call

        section = rfe_case.rfe_sections.find_by(title: "Specialty Occupation Issue")
        expect(section).to be_present
        expect(section.section_type).to eq("specialty_occupation")
        expect(section.original_text).to eq("USCIS requires evidence that the position qualifies as a specialty occupation.")
        expect(section.summary).to eq("The petitioner must demonstrate the position meets specialty occupation criteria.")
        expect(section.cfr_reference).to eq("8 CFR 214.2(h)(4)(ii)")
        expect(section.confidence_score).to eq(0.92)
        expect(section.position).to eq(0)
      end

      it "creates evidence checklists with correct attributes" do
        described_class.new(rfe_case.id).call

        section = rfe_case.rfe_sections.find_by(title: "Specialty Occupation Issue")
        checklist = section.evidence_checklists.find_by(document_name: "Expert Opinion Letter")
        expect(checklist).to be_present
        expect(checklist.priority).to eq("required")
        expect(checklist.description).to eq("Letter from industry expert confirming specialty nature")
        expect(checklist.guidance).to eq("Should reference specific degree requirements")
        expect(checklist.is_collected).to be false
      end

      it "transitions the case to review status" do
        described_class.new(rfe_case.id).call

        rfe_case.reload
        expect(rfe_case.status).to eq("review")
      end

      it "sets ai_analysis metadata on sections" do
        described_class.new(rfe_case.id).call

        section = rfe_case.rfe_sections.first
        expect(section.ai_analysis).to include("model" => "gpt-4o")
        expect(section.ai_analysis).to have_key("analyzed_at")
        expect(section.ai_analysis).to have_key("raw_section")
      end
    end

    context "when OpenAI returns invalid JSON" do
      before do
        allow(openai_client).to receive(:chat).and_return(
          { "choices" => [{ "message" => { "content" => "not valid json {{{" } }] }
        )
      end

      it "does not create any sections" do
        expect { described_class.new(rfe_case.id).call }.not_to change { RfeSection.count }
      end

      it "updates progress to failed" do
        described_class.new(rfe_case.id).call

        rfe_case.reload
        expect(rfe_case.metadata["analysis_progress"]).to eq("failed")
        expect(rfe_case.metadata["analysis_error"]).to eq("AI returned invalid JSON")
      end
    end

    context "when OpenAI raises a Faraday::Error" do
      before do
        allow(openai_client).to receive(:chat).and_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "does not create any sections" do
        expect { described_class.new(rfe_case.id).call }.not_to change { RfeSection.count }
      end

      it "updates progress to failed with service unavailable message" do
        described_class.new(rfe_case.id).call

        rfe_case.reload
        expect(rfe_case.metadata["analysis_progress"]).to eq("failed")
        expect(rfe_case.metadata["analysis_error"]).to eq("AI service unavailable")
      end
    end

    context "when OpenAI returns empty sections array" do
      before do
        response = { "choices" => [{ "message" => { "content" => { "sections" => [] }.to_json } }] }
        allow(openai_client).to receive(:chat).and_return(response)
      end

      it "does not create any sections" do
        expect { described_class.new(rfe_case.id).call }.not_to change { RfeSection.count }
      end

      it "does not create any evidence checklists" do
        expect { described_class.new(rfe_case.id).call }.not_to change { EvidenceChecklist.count }
      end

      it "transitions the case to review" do
        described_class.new(rfe_case.id).call

        rfe_case.reload
        expect(rfe_case.status).to eq("review")
      end
    end

    context "when section_type is invalid" do
      before do
        analysis = {
          "sections" => [
            {
              "title" => "Unknown Issue",
              "section_type" => "nonexistent_type",
              "original_text" => "Some text",
              "summary" => "Some summary",
              "confidence_score" => 0.8,
              "evidence_needed" => []
            }
          ]
        }
        response = { "choices" => [{ "message" => { "content" => analysis.to_json } }] }
        allow(openai_client).to receive(:chat).and_return(response)
      end

      it "falls back to 'general' section type" do
        described_class.new(rfe_case.id).call

        section = rfe_case.rfe_sections.first
        expect(section.section_type).to eq("general")
      end
    end

    context "when priority is invalid" do
      before do
        analysis = {
          "sections" => [
            {
              "title" => "Test Section",
              "section_type" => "general",
              "original_text" => "Some text",
              "summary" => "Some summary",
              "confidence_score" => 0.8,
              "evidence_needed" => [
                {
                  "document_name" => "Some Document",
                  "description" => "Description",
                  "guidance" => "Guidance",
                  "priority" => "super_critical"
                }
              ]
            }
          ]
        }
        response = { "choices" => [{ "message" => { "content" => analysis.to_json } }] }
        allow(openai_client).to receive(:chat).and_return(response)
      end

      it "falls back to 'recommended' priority" do
        described_class.new(rfe_case.id).call

        checklist = rfe_case.evidence_checklists.first
        expect(checklist.priority).to eq("recommended")
      end
    end

    context "when confidence score is greater than 1.0" do
      before do
        analysis = {
          "sections" => [
            {
              "title" => "High Confidence",
              "section_type" => "general",
              "original_text" => "Some text",
              "summary" => "Some summary",
              "confidence_score" => 1.5,
              "evidence_needed" => []
            }
          ]
        }
        response = { "choices" => [{ "message" => { "content" => analysis.to_json } }] }
        allow(openai_client).to receive(:chat).and_return(response)
      end

      it "clamps the confidence score to 1.0" do
        described_class.new(rfe_case.id).call

        section = rfe_case.rfe_sections.first
        expect(section.confidence_score).to eq(1.0)
      end
    end

    context "when confidence score is less than 0.0" do
      before do
        analysis = {
          "sections" => [
            {
              "title" => "Low Confidence",
              "section_type" => "general",
              "original_text" => "Some text",
              "summary" => "Some summary",
              "confidence_score" => -0.3,
              "evidence_needed" => []
            }
          ]
        }
        response = { "choices" => [{ "message" => { "content" => analysis.to_json } }] }
        allow(openai_client).to receive(:chat).and_return(response)
      end

      it "clamps the confidence score to 0.0" do
        described_class.new(rfe_case.id).call

        section = rfe_case.rfe_sections.first
        expect(section.confidence_score).to eq(0.0)
      end
    end

    context "when re-analyzing replaces existing sections" do
      before do
        allow(openai_client).to receive(:chat).and_return(openai_chat_response)

        # Create pre-existing sections and checklists
        existing_section = create(:rfe_section, tenant: tenant, case: rfe_case, title: "Old Section")
        create(:evidence_checklist, tenant: tenant, case: rfe_case, rfe_section: existing_section)
      end

      it "destroys old sections and creates new ones" do
        service = described_class.new(rfe_case.id)
        service.call

        rfe_case.reload
        expect(rfe_case.rfe_sections.count).to eq(2)
        expect(rfe_case.rfe_sections.pluck(:title)).not_to include("Old Section")
      end

      it "destroys old evidence checklists" do
        service = described_class.new(rfe_case.id)

        expect { service.call }.to change { rfe_case.evidence_checklists.count }
        expect(rfe_case.evidence_checklists.count).to eq(3)
      end
    end

    context "when case is not found" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.new("00000000-0000-0000-0000-000000000000")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when there are no documents (empty text)" do
      before do
        allow(TextExtractionService).to receive(:new).and_return(
          instance_double(TextExtractionService, call: nil)
        )
      end

      it "does not call OpenAI" do
        expect(openai_client).not_to receive(:chat)
        described_class.new(rfe_case.id).call
      end

      it "updates progress to failed with appropriate message" do
        described_class.new(rfe_case.id).call

        rfe_case.reload
        expect(rfe_case.metadata["analysis_progress"]).to eq("failed")
        expect(rfe_case.metadata["analysis_error"]).to eq("No text could be extracted from uploaded documents")
      end
    end

    context "progress updates through stages" do
      before do
        allow(openai_client).to receive(:chat).and_return(openai_chat_response)
      end

      it "reaches complete status after successful analysis" do
        described_class.new(rfe_case.id).call

        rfe_case.reload
        metadata = rfe_case.metadata.transform_keys(&:to_s)
        expect(metadata["analysis_progress"]).to eq("complete")
      end
    end
  end
end
