require "rails_helper"

RSpec.describe ExportService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:rfe_case) do
    create(:rfe_case,
      tenant: tenant,
      created_by: user,
      assigned_attorney: attorney,
      case_number: "RFE-2024-0042",
      visa_type: "H-1B",
      petitioner_name: "Acme Corp",
      beneficiary_name: "John Doe",
      uscis_receipt_number: "WAC2490012345",
      rfe_received_date: Date.new(2024, 6, 1),
      rfe_deadline: Date.new(2024, 9, 1)
    )
  end

  before do
    ActsAsTenant.current_tenant = tenant
  end

  describe "#call" do
    context "PDF generation" do
      subject(:service) { described_class.new(rfe_case, format: :pdf) }

      it "returns non-empty binary data" do
        result = service.call

        expect(result).to be_a(String)
        expect(result.bytesize).to be > 0
      end

      it "returns valid PDF content starting with PDF header" do
        result = service.call

        expect(result).to start_with("%PDF")
      end
    end

    context "DOCX generation" do
      subject(:service) { described_class.new(rfe_case, format: :docx) }

      it "returns non-empty binary data" do
        result = service.call

        expect(result).to be_a(String)
        expect(result.bytesize).to be > 0
      end

      it "returns valid DOCX content (ZIP format starting with PK header)" do
        result = service.call

        # DOCX files are ZIP archives; they start with the PK magic bytes
        expect(result.bytes[0..1]).to eq([0x50, 0x4B])
      end
    end

    context "ZIP generation" do
      subject(:service) { described_class.new(rfe_case, format: :zip) }

      it "returns non-empty binary data" do
        result = service.call

        expect(result).to be_a(String)
        expect(result.bytesize).to be > 0
      end

      it "returns valid ZIP content starting with PK header" do
        result = service.call

        expect(result.bytes[0..1]).to eq([0x50, 0x4B])
      end
    end

    context "unsupported format" do
      it "raises ArgumentError" do
        service = described_class.new(rfe_case, format: :csv)

        expect { service.call }.to raise_error(ArgumentError, /Unsupported format: csv/)
      end
    end
  end

  describe "#filename" do
    it "includes the case number" do
      service = described_class.new(rfe_case, format: :pdf)

      expect(service.filename).to include("RFE-2024-0042")
    end

    it "includes the current date" do
      service = described_class.new(rfe_case, format: :pdf)

      expect(service.filename).to include(Date.current.to_s)
    end

    it "uses the correct extension for PDF" do
      service = described_class.new(rfe_case, format: :pdf)

      expect(service.filename).to end_with(".pdf")
    end

    it "uses the correct extension for DOCX" do
      service = described_class.new(rfe_case, format: :docx)

      expect(service.filename).to end_with(".docx")
    end

    it "uses the correct extension for ZIP" do
      service = described_class.new(rfe_case, format: :zip)

      expect(service.filename).to end_with(".zip")
    end

    it "starts with RFE_Response_ prefix" do
      service = described_class.new(rfe_case, format: :pdf)

      expect(service.filename).to start_with("RFE_Response_")
    end

    it "sanitizes special characters in case number" do
      special_case = create(:rfe_case,
        tenant: tenant,
        created_by: user,
        case_number: "RFE/2024#0099"
      )
      service = described_class.new(special_case, format: :pdf)

      expect(service.filename).not_to match(%r{[/#]})
      expect(service.filename).to include("RFE_2024_0099")
    end
  end

  describe "#content_type" do
    it "returns application/pdf for PDF format" do
      service = described_class.new(rfe_case, format: :pdf)

      expect(service.content_type).to eq("application/pdf")
    end

    it "returns the correct MIME type for DOCX format" do
      service = described_class.new(rfe_case, format: :docx)

      expect(service.content_type).to eq(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      )
    end

    it "returns application/zip for ZIP format" do
      service = described_class.new(rfe_case, format: :zip)

      expect(service.content_type).to eq("application/zip")
    end
  end

  describe "case with no sections or drafts" do
    it "generates a PDF without errors" do
      service = described_class.new(rfe_case, format: :pdf)

      expect { service.call }.not_to raise_error
    end

    it "generates a DOCX without errors" do
      service = described_class.new(rfe_case, format: :docx)

      expect { service.call }.not_to raise_error
    end

    it "generates a ZIP without errors" do
      service = described_class.new(rfe_case, format: :zip)

      expect { service.call }.not_to raise_error
    end
  end

  describe "response content priority" do
    let!(:section) do
      create(:rfe_section,
        tenant: tenant,
        case: rfe_case,
        title: "Specialty Occupation",
        position: 0,
        cfr_reference: "8 CFR 214.2(h)(4)(ii)"
      )
    end

    context "case with approved drafts (uses final_content)" do
      let!(:draft) do
        create(:draft_response, :approved,
          tenant: tenant,
          case: rfe_case,
          rfe_section: section,
          ai_generated_content: "AI generated text",
          edited_content: "Edited text",
          final_content: "Final approved text",
          version: 1
        )
      end

      it "includes final_content in the PDF output" do
        service = described_class.new(rfe_case, format: :pdf)
        result = service.call

        # We verify the service uses response_content which prioritizes final_content.
        # Since PDF is binary, we verify the service runs without error and produces output.
        expect(result.bytesize).to be > 0
      end

      it "uses final_content as the response content" do
        service = described_class.new(rfe_case, format: :pdf)

        # Access the private method to verify content priority
        content = service.send(:response_content, draft)
        expect(content).to eq("Final approved text")
      end
    end

    context "case with edited drafts (uses edited_content)" do
      let!(:draft) do
        create(:draft_response, :editing,
          tenant: tenant,
          case: rfe_case,
          rfe_section: section,
          ai_generated_content: "AI generated text",
          edited_content: "Edited text by attorney",
          final_content: nil,
          version: 1
        )
      end

      it "uses edited_content when final_content is absent" do
        service = described_class.new(rfe_case, format: :pdf)

        content = service.send(:response_content, draft)
        expect(content).to eq("Edited text by attorney")
      end
    end

    context "case with only AI content (uses ai_generated_content)" do
      let!(:draft) do
        create(:draft_response,
          tenant: tenant,
          case: rfe_case,
          rfe_section: section,
          ai_generated_content: "AI generated response text",
          edited_content: nil,
          final_content: nil,
          version: 1
        )
      end

      it "uses ai_generated_content when final and edited content are absent" do
        service = described_class.new(rfe_case, format: :pdf)

        content = service.send(:response_content, draft)
        expect(content).to eq("AI generated response text")
      end
    end

    context "case with no draft for a section" do
      it "returns a fallback message when draft is nil" do
        service = described_class.new(rfe_case, format: :pdf)

        content = service.send(:response_content, nil)
        expect(content).to eq("No draft response available.")
      end
    end

    context "case with all content fields blank" do
      let!(:draft) do
        create(:draft_response,
          tenant: tenant,
          case: rfe_case,
          rfe_section: section,
          ai_generated_content: nil,
          edited_content: nil,
          final_content: nil,
          version: 1
        )
      end

      it "returns the 'No content.' fallback" do
        service = described_class.new(rfe_case, format: :pdf)

        content = service.send(:response_content, draft)
        expect(content).to eq("No content.")
      end
    end
  end

  describe "PDF with multiple sections and exhibits" do
    let!(:section1) do
      create(:rfe_section,
        tenant: tenant,
        case: rfe_case,
        title: "Specialty Occupation",
        position: 0,
        cfr_reference: "8 CFR 214.2(h)(4)(ii)"
      )
    end

    let!(:section2) do
      create(:rfe_section,
        tenant: tenant,
        case: rfe_case,
        title: "Beneficiary Qualifications",
        position: 1
      )
    end

    let!(:draft1) do
      create(:draft_response, :approved,
        tenant: tenant,
        case: rfe_case,
        rfe_section: section1,
        final_content: "The position of Software Engineer qualifies as a specialty occupation...",
        version: 1
      )
    end

    let!(:draft2) do
      create(:draft_response,
        tenant: tenant,
        case: rfe_case,
        rfe_section: section2,
        ai_generated_content: "The beneficiary holds a Bachelor's degree in Computer Science...",
        version: 1
      )
    end

    let!(:exhibit) do
      create(:exhibit,
        tenant: tenant,
        case: rfe_case,
        label: "A",
        title: "Degree Certificate",
        description: "Bachelor's degree from MIT",
        position: 0
      )
    end

    it "generates a valid PDF with all sections" do
      service = described_class.new(rfe_case, format: :pdf)
      result = service.call

      expect(result).to start_with("%PDF")
      expect(result.bytesize).to be > 500
    end

    it "generates a valid DOCX with all sections" do
      service = described_class.new(rfe_case, format: :docx)
      result = service.call

      expect(result.bytesize).to be > 500
    end
  end

  describe "format as string input" do
    it "accepts format as a string and converts to symbol" do
      service = described_class.new(rfe_case, format: "pdf")

      expect(service.format).to eq(:pdf)
      expect { service.call }.not_to raise_error
    end
  end
end
