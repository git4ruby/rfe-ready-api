require "rails_helper"

RSpec.describe RfeDocument, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:document_type) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:case).class_name("RfeCase") }
    it { is_expected.to belong_to(:uploaded_by).class_name("User") }
    it { is_expected.to have_many(:rfe_sections).dependent(:nullify) }
    it { is_expected.to have_many(:exhibits).dependent(:nullify) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:document_type).with_values(rfe_notice: 0, supporting_evidence: 1, exhibit: 2) }
    it { is_expected.to define_enum_for(:processing_status).with_prefix(:processing).with_values(pending: 0, processing: 1, completed: 2, failed: 3) }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

    describe ".rfe_notices" do
      it "returns only rfe_notice documents" do
        notice = create(:rfe_document, :rfe_notice, tenant: tenant, case: rfe_case, uploaded_by: user)
        evidence = create(:rfe_document, :supporting_evidence, tenant: tenant, case: rfe_case, uploaded_by: user)

        expect(RfeDocument.rfe_notices).to include(notice)
        expect(RfeDocument.rfe_notices).not_to include(evidence)
      end
    end

    describe ".needs_processing" do
      it "returns only pending documents" do
        pending_doc = create(:rfe_document, tenant: tenant, case: rfe_case, uploaded_by: user, processing_status: :pending)
        processed = create(:rfe_document, :processed, tenant: tenant, case: rfe_case, uploaded_by: user)

        expect(RfeDocument.needs_processing).to include(pending_doc)
        expect(RfeDocument.needs_processing).not_to include(processed)
      end
    end
  end
end
