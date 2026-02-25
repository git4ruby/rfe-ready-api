require "rails_helper"

RSpec.describe TextExtractionService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  describe "#call" do
    context "plain text extraction" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          content_type: "text/plain",
          processing_status: :pending
        )
      end
      let(:file_content) { "This is plain text content from an RFE notice." }

      before do
        # Attach a fake file using ActiveStorage
        document.file.attach(
          io: StringIO.new(file_content),
          filename: "rfe_notice.txt",
          content_type: "text/plain"
        )
      end

      it "extracts text from the file" do
        result = described_class.new(document).call

        expect(result).to eq(file_content)
      end

      it "sets extracted_text on the document" do
        described_class.new(document).call
        document.reload

        expect(document.extracted_text).to eq(file_content)
      end

      it "sets processing_status to completed" do
        described_class.new(document).call
        document.reload

        expect(document).to be_processing_completed
      end
    end

    context "PDF extraction" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          content_type: "application/pdf",
          processing_status: :pending
        )
      end

      let(:page1) { instance_double("PDF::Reader::Page", text: "Page 1 content about specialty occupation.") }
      let(:page2) { instance_double("PDF::Reader::Page", text: "Page 2 content about beneficiary qualifications.") }
      let(:pdf_reader) { instance_double(PDF::Reader, pages: [page1, page2]) }

      before do
        # Attach a dummy PDF file (binary content does not matter since we mock PDF::Reader)
        document.file.attach(
          io: StringIO.new("fake pdf binary content"),
          filename: "rfe_notice.pdf",
          content_type: "application/pdf"
        )

        allow(PDF::Reader).to receive(:new).and_return(pdf_reader)
      end

      it "extracts text from all PDF pages" do
        result = described_class.new(document).call

        expect(result).to eq(
          "Page 1 content about specialty occupation.\n\nPage 2 content about beneficiary qualifications."
        )
      end

      it "joins pages with double newlines" do
        result = described_class.new(document).call

        expect(result).to include("\n\n")
        expect(result.split("\n\n").length).to eq(2)
      end

      it "sets the extracted_text on the document" do
        described_class.new(document).call
        document.reload

        expect(document.extracted_text).to include("Page 1 content")
        expect(document.extracted_text).to include("Page 2 content")
      end

      it "sets processing_status to completed" do
        described_class.new(document).call
        document.reload

        expect(document).to be_processing_completed
      end
    end

    context "processing failure" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          content_type: "application/pdf",
          processing_status: :pending
        )
      end

      before do
        document.file.attach(
          io: StringIO.new("corrupt pdf data"),
          filename: "corrupt.pdf",
          content_type: "application/pdf"
        )

        allow(PDF::Reader).to receive(:new).and_raise(StandardError, "Failed to parse PDF structure")
      end

      it "sets processing_status to failed" do
        expect {
          described_class.new(document).call
        }.to raise_error(StandardError, "Failed to parse PDF structure")

        document.reload
        expect(document).to be_processing_failed
      end

      it "stores the error message in processing_metadata" do
        begin
          described_class.new(document).call
        rescue StandardError
          # expected
        end

        document.reload
        expect(document.processing_metadata["error"]).to eq("Failed to parse PDF structure")
      end

      it "stores failed_at timestamp in processing_metadata" do
        begin
          described_class.new(document).call
        rescue StandardError
          # expected
        end

        document.reload
        expect(document.processing_metadata["failed_at"]).to be_present
      end

      it "re-raises the error" do
        expect {
          described_class.new(document).call
        }.to raise_error(StandardError, "Failed to parse PDF structure")
      end
    end

    context "no file attached" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          processing_status: :pending
        )
      end

      it "returns nil" do
        result = described_class.new(document).call

        expect(result).to be_nil
      end

      it "does not update processing_status" do
        described_class.new(document).call
        document.reload

        expect(document.processing_status).to eq("pending")
      end
    end

    context "unknown content type falls back to plain text" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          content_type: "application/octet-stream",
          processing_status: :pending
        )
      end
      let(:file_content) { "Some raw binary-ish text content" }

      before do
        document.file.attach(
          io: StringIO.new(file_content),
          filename: "unknown_file.bin",
          content_type: "application/octet-stream"
        )
      end

      it "extracts text using plain text fallback" do
        result = described_class.new(document).call

        expect(result).to eq(file_content)
      end

      it "sets processing_status to completed" do
        described_class.new(document).call
        document.reload

        expect(document).to be_processing_completed
      end

      it "sets extracted_text on the document" do
        described_class.new(document).call
        document.reload

        expect(document.extracted_text).to eq(file_content)
      end
    end

    context "DOCX extraction" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          processing_status: :pending
        )
      end

      let(:docx_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
              <w:p><w:r><w:t>First paragraph of the document.</w:t></w:r></w:p>
              <w:p><w:r><w:t>Second paragraph with more details.</w:t></w:r></w:p>
            </w:body>
          </w:document>
        XML
      end

      before do
        # Create a minimal valid DOCX (ZIP) file containing word/document.xml
        require "zip"
        buffer = Zip::OutputStream.write_buffer do |zip|
          zip.put_next_entry("word/document.xml")
          zip.write(docx_xml)
        end

        document.file.attach(
          io: StringIO.new(buffer.string),
          filename: "document.docx",
          content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
      end

      it "extracts text from DOCX paragraphs" do
        result = described_class.new(document).call

        expect(result).to include("First paragraph of the document.")
        expect(result).to include("Second paragraph with more details.")
      end

      it "sets processing_status to completed" do
        described_class.new(document).call
        document.reload

        expect(document).to be_processing_completed
      end
    end

    context "malformed PDF falls back to plain text" do
      let(:document) do
        create(:rfe_document,
          tenant: tenant,
          case: rfe_case,
          uploaded_by: user,
          content_type: "application/pdf",
          processing_status: :pending
        )
      end
      let(:raw_content) { "This is not actually a valid PDF file" }

      before do
        document.file.attach(
          io: StringIO.new(raw_content),
          filename: "bad.pdf",
          content_type: "application/pdf"
        )

        allow(PDF::Reader).to receive(:new).and_raise(
          PDF::Reader::MalformedPDFError, "not a valid PDF"
        )
      end

      it "falls back to plain text extraction" do
        result = described_class.new(document).call

        expect(result).to eq(raw_content)
      end

      it "sets processing_status to completed despite the PDF error" do
        described_class.new(document).call
        document.reload

        expect(document).to be_processing_completed
      end
    end
  end
end
