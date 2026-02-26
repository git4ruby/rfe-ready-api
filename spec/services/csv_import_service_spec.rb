require "rails_helper"

RSpec.describe CsvImportService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  describe "#call" do
    context "with a valid CSV" do
      let(:csv_content) { "case_number,visa_type,petitioner_name\nRFE-001,H-1B,Acme Corp\nRFE-002,L-1A,Globex Inc\n" }
      let(:file) { StringIO.new(csv_content) }

      it "imports all rows successfully" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(2)
        expect(result[:imported]).to eq(2)
        expect(result[:failed]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it "creates RfeCase records in the database" do
        service = described_class.new(file: file, tenant: tenant, user: user)

        expect {
          service.call
        }.to change(RfeCase, :count).by(2)
      end

      it "assigns the correct tenant and user to imported cases" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        service.call

        rfe_case = RfeCase.find_by(case_number: "RFE-001")
        expect(rfe_case.tenant).to eq(tenant)
        expect(rfe_case.created_by).to eq(user)
        expect(rfe_case.visa_type).to eq("H-1B")
        expect(rfe_case.petitioner_name).to eq("Acme Corp")
      end
    end

    context "with optional columns included" do
      let(:csv_content) do
        "case_number,visa_type,petitioner_name,beneficiary_name,uscis_receipt_number,rfe_received_date,rfe_deadline,notes\n" \
        "RFE-001,H-1B,Acme Corp,John Doe,WAC2490012345,2024-06-01,2024-09-01,Urgent case\n"
      end
      let(:file) { StringIO.new(csv_content) }

      it "imports optional fields correctly" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        service.call

        rfe_case = RfeCase.find_by(case_number: "RFE-001")
        expect(rfe_case.beneficiary_name).to eq("John Doe")
        expect(rfe_case.uscis_receipt_number).to eq("WAC2490012345")
        expect(rfe_case.notes).to eq("Urgent case")
      end
    end

    context "with optional columns left blank" do
      let(:csv_content) { "case_number,visa_type,petitioner_name,beneficiary_name,notes\nRFE-001,H-1B,Acme Corp,,\n" }
      let(:file) { StringIO.new(csv_content) }

      it "imports the row successfully with blank optional fields" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:imported]).to eq(1)
        expect(result[:failed]).to eq(0)

        rfe_case = RfeCase.find_by(case_number: "RFE-001")
        expect(rfe_case.beneficiary_name).to be_nil
        expect(rfe_case.notes).to be_nil
      end
    end

    context "with missing required columns in header" do
      let(:csv_content) { "case_number,petitioner_name\nRFE-001,Acme Corp\n" }
      let(:file) { StringIO.new(csv_content) }

      it "returns an error about missing columns" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(0)
        expect(result[:imported]).to eq(0)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first[:row]).to eq(0)
        expect(result[:errors].first[:message]).to include("Missing required columns")
        expect(result[:errors].first[:message]).to include("visa_type")
      end

      it "does not create any records" do
        service = described_class.new(file: file, tenant: tenant, user: user)

        expect {
          service.call
        }.not_to change(RfeCase, :count)
      end
    end

    context "with missing required field values in rows" do
      let(:csv_content) { "case_number,visa_type,petitioner_name\nRFE-001,,Acme Corp\n,H-1B,Globex Inc\n" }
      let(:file) { StringIO.new(csv_content) }

      it "reports errors with correct row numbers" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(2)
        expect(result[:failed]).to eq(2)
        expect(result[:imported]).to eq(0)
        expect(result[:errors].size).to eq(2)

        # Row 2 (first data row) is missing visa_type
        expect(result[:errors][0][:row]).to eq(2)
        expect(result[:errors][0][:message]).to include("visa_type")

        # Row 3 (second data row) is missing case_number
        expect(result[:errors][1][:row]).to eq(3)
        expect(result[:errors][1][:message]).to include("case_number")
      end
    end

    context "with duplicate case numbers" do
      let(:csv_content) { "case_number,visa_type,petitioner_name\nRFE-DUP,H-1B,Acme Corp\n" }
      let(:file) { StringIO.new(csv_content) }

      before do
        create(:rfe_case, tenant: tenant, created_by: user, case_number: "RFE-DUP")
      end

      it "reports the duplicate as a failure with row number" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(1)
        expect(result[:imported]).to eq(0)
        expect(result[:failed]).to eq(1)
        expect(result[:errors].first[:row]).to eq(2)
        expect(result[:errors].first[:message]).to match(/case number/i)
      end
    end

    context "with malformed CSV" do
      let(:csv_content) { "case_number,visa_type,petitioner_name\n\"unclosed quote,H-1B,Acme" }
      let(:file) { StringIO.new(csv_content) }

      it "returns an error about invalid CSV format" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(0)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first[:row]).to eq(0)
        expect(result[:errors].first[:message]).to include("Invalid CSV format")
      end
    end

    context "with partial success (some valid, some invalid rows)" do
      let(:csv_content) do
        "case_number,visa_type,petitioner_name\n" \
        "RFE-OK1,H-1B,Acme Corp\n" \
        ",H-1B,Missing CaseNum\n" \
        "RFE-OK2,L-1A,Globex Inc\n"
      end
      let(:file) { StringIO.new(csv_content) }

      it "counts total, imported, and failed correctly" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(3)
        expect(result[:imported]).to eq(2)
        expect(result[:failed]).to eq(1)
        expect(result[:errors].size).to eq(1)
      end
    end

    context "with extra columns in the CSV" do
      let(:csv_content) { "case_number,visa_type,petitioner_name,extra_column,another_extra\nRFE-001,H-1B,Acme Corp,ignore_me,also_ignore\n" }
      let(:file) { StringIO.new(csv_content) }

      it "ignores extra columns and imports successfully" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:imported]).to eq(1)
        expect(result[:failed]).to eq(0)
      end
    end

    context "with an empty CSV (headers only)" do
      let(:csv_content) { "case_number,visa_type,petitioner_name\n" }
      let(:file) { StringIO.new(csv_content) }

      it "returns zero total with no errors" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:total]).to eq(0)
        expect(result[:imported]).to eq(0)
        expect(result[:failed]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end

    context "with whitespace in values" do
      let(:csv_content) { "case_number,visa_type,petitioner_name\n  RFE-001  ,  H-1B  ,  Acme Corp  \n" }
      let(:file) { StringIO.new(csv_content) }

      it "strips whitespace from values" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        service.call

        rfe_case = RfeCase.find_by(case_number: "RFE-001")
        expect(rfe_case).to be_present
        expect(rfe_case.visa_type).to eq("H-1B")
        expect(rfe_case.petitioner_name).to eq("Acme Corp")
      end
    end

    context "with mixed-case headers" do
      let(:csv_content) { "Case_Number,Visa_Type,Petitioner_Name\nRFE-001,H-1B,Acme Corp\n" }
      let(:file) { StringIO.new(csv_content) }

      it "normalizes headers to lowercase and imports successfully" do
        service = described_class.new(file: file, tenant: tenant, user: user)
        result = service.call

        expect(result[:imported]).to eq(1)
        expect(result[:failed]).to eq(0)
      end
    end
  end
end
