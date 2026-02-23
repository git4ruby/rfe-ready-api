require "rails_helper"

RSpec.describe AuditLog, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:action) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:auditable) }
  end

  describe "scopes" do
    let(:user) { create(:user, tenant: tenant) }
    let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

    describe ".recent" do
      it "orders by created_at desc" do
        old_log = create(:audit_log, tenant: tenant, user: user, auditable: rfe_case, created_at: 2.days.ago)
        new_log = create(:audit_log, tenant: tenant, user: user, auditable: rfe_case, created_at: 1.hour.ago)

        recent_ids = AuditLog.recent.pluck(:id)
        expect(recent_ids.index(new_log.id)).to be < recent_ids.index(old_log.id)
      end
    end

    describe ".by_action" do
      it "filters by action type" do
        create_log = create(:audit_log, tenant: tenant, user: user, auditable: rfe_case, action: "create")
        update_log = create(:audit_log, tenant: tenant, user: user, auditable: rfe_case, action: "update")

        expect(AuditLog.by_action("create")).to include(create_log)
        expect(AuditLog.by_action("create")).not_to include(update_log)
      end
    end
  end
end

RSpec.describe Auditable, type: :model do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }

  before do
    set_tenant(tenant)
    Current.user = user
  end

  after do
    Current.user = nil
  end

  it "creates an audit log on create" do
    expect {
      create(:knowledge_doc, tenant: tenant, uploaded_by: user)
    }.to change(AuditLog, :count).by(1)

    log = AuditLog.order(created_at: :desc).first
    expect(log.action).to eq("create")
    expect(log.tenant).to eq(tenant)
    expect(log.auditable_type).to eq("KnowledgeDoc")
  end

  it "creates an audit log on update with changes" do
    doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user)

    expect {
      doc.update!(title: "Updated Title")
    }.to change(AuditLog, :count).by(1)

    log = AuditLog.order(created_at: :desc).first
    expect(log.action).to eq("update")
    expect(log.changes_data).to have_key("title")
  end

  it "creates an audit log on destroy" do
    doc = create(:knowledge_doc, tenant: tenant, uploaded_by: user)

    expect {
      doc.destroy!
    }.to change(AuditLog, :count).by(1)

    log = AuditLog.order(created_at: :desc).first
    expect(log.action).to eq("destroy")
  end

  it "does not raise if audit log creation fails" do
    allow(AuditLog).to receive(:create!).and_raise(StandardError.new("DB error"))

    expect {
      create(:knowledge_doc, tenant: tenant, uploaded_by: user)
    }.not_to raise_error
  end
end
