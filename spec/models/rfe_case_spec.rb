require "rails_helper"

RSpec.describe RfeCase, type: :model do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    subject { build(:rfe_case, tenant: tenant, created_by: user) }

    it { is_expected.to validate_presence_of(:case_number) }
    it "validates uniqueness of case_number within tenant" do
      existing = create(:rfe_case, tenant: tenant, created_by: user)
      duplicate = build(:rfe_case, tenant: tenant, created_by: user, case_number: existing.case_number)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:case_number]).to include("has already been taken")
    end
    it { is_expected.to validate_presence_of(:visa_type) }
    it { is_expected.to validate_presence_of(:petitioner_name) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to belong_to(:assigned_attorney).class_name("User").optional }
    it { is_expected.to have_many(:rfe_documents).dependent(:destroy) }
    it { is_expected.to have_many(:rfe_sections).dependent(:destroy) }
    it { is_expected.to have_many(:evidence_checklists).dependent(:destroy) }
    it { is_expected.to have_many(:draft_responses).dependent(:destroy) }
    it { is_expected.to have_many(:exhibits).dependent(:destroy) }
  end

  describe "encryption" do
    it "encrypts beneficiary_name" do
      rfe_case = create(:rfe_case, tenant: tenant, created_by: user, beneficiary_name: "John Smith")
      expect(rfe_case.beneficiary_name).to eq("John Smith")
      expect(rfe_case.beneficiary_name_ciphertext).not_to eq("John Smith")
      expect(rfe_case.beneficiary_name_ciphertext).to be_present
    end
  end

  describe "scopes" do
    describe ".active" do
      it "excludes archived cases" do
        active_case = create(:rfe_case, :draft, tenant: tenant, created_by: user)
        archived_case = create(:rfe_case, :archived, tenant: tenant, created_by: user)

        expect(RfeCase.active).to include(active_case)
        expect(RfeCase.active).not_to include(archived_case)
      end
    end

    describe ".approaching_deadline" do
      it "returns cases with deadline within 14 days" do
        approaching = create(:rfe_case, :approaching_deadline, tenant: tenant, created_by: user)
        far_away = create(:rfe_case, :with_deadline, tenant: tenant, created_by: user)

        expect(RfeCase.approaching_deadline).to include(approaching)
        expect(RfeCase.approaching_deadline).not_to include(far_away)
      end

      it "excludes archived cases" do
        archived = create(:rfe_case, :archived, tenant: tenant, created_by: user, rfe_deadline: 3.days.from_now)
        expect(RfeCase.approaching_deadline).not_to include(archived)
      end
    end
  end

  describe "AASM state machine" do
    let(:rfe_case) { create(:rfe_case, :draft, tenant: tenant, created_by: user) }

    describe "initial state" do
      it "starts as draft" do
        expect(rfe_case.aasm.current_state).to eq(:draft)
      end
    end

    describe "#start_analysis" do
      it "transitions from draft to analyzing" do
        expect { rfe_case.start_analysis! }.to change(rfe_case, :status).from("draft").to("analyzing")
      end

      it "cannot transition from review" do
        rfe_case.update_column(:status, "review")
        expect { rfe_case.start_analysis! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe "#complete_analysis" do
      it "transitions from analyzing to review" do
        rfe_case.update_column(:status, "analyzing")
        expect { rfe_case.complete_analysis! }.to change(rfe_case, :status).from("analyzing").to("review")
      end
    end

    describe "#mark_responded" do
      it "transitions from review to responded" do
        rfe_case.update_column(:status, "review")
        expect { rfe_case.mark_responded! }.to change(rfe_case, :status).from("review").to("responded")
      end
    end

    describe "#archive" do
      %w[draft review responded].each do |from_state|
        it "transitions from #{from_state} to archived" do
          rfe_case.update_column(:status, from_state)
          expect { rfe_case.archive! }.to change(rfe_case, :status).from(from_state).to("archived")
        end
      end

      it "cannot archive from analyzing" do
        rfe_case.update_column(:status, "analyzing")
        expect { rfe_case.archive! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe "#reopen" do
      it "transitions from archived to draft" do
        rfe_case.update_column(:status, "archived")
        expect { rfe_case.reopen! }.to change(rfe_case, :status).from("archived").to("draft")
      end

      it "cannot reopen from draft" do
        expect { rfe_case.reopen! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe "tenant scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_user) { create(:user, tenant: other_tenant) }

    it "scopes cases to the current tenant" do
      my_case = create(:rfe_case, tenant: tenant, created_by: user)
      with_tenant(other_tenant) do
        create(:rfe_case, tenant: other_tenant, created_by: other_user)
      end

      expect(RfeCase.all).to contain_exactly(my_case)
    end
  end
end
