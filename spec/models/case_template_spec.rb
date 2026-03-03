require "rails_helper"

RSpec.describe CaseTemplate, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:visa_category) }
    it { is_expected.to validate_presence_of(:default_sections) }
    it { is_expected.to validate_presence_of(:default_checklist) }

    describe "name uniqueness scoped to tenant" do
      let!(:existing) { create(:case_template, tenant: tenant, name: "Unique Name") }

      it "does not allow duplicate names within the same tenant" do
        duplicate = build(:case_template, tenant: tenant, name: "Unique Name")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include("has already been taken")
      end

      it "allows the same name in a different tenant" do
        other_tenant = create(:tenant)
        ActsAsTenant.current_tenant = other_tenant
        other = build(:case_template, tenant: other_tenant, name: "Unique Name")
        expect(other).to be_valid
      end
    end
  end
end
