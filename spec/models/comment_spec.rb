require "rails_helper"

RSpec.describe Comment, type: :model do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:case).class_name("RfeCase") }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:parent).class_name("Comment").optional }
    it { is_expected.to have_many(:replies).class_name("Comment").dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:body) }
  end

  describe "scopes" do
    let!(:top_level) { create(:comment, case: rfe_case, tenant: tenant, user: user) }
    let!(:reply) { create(:comment, case: rfe_case, tenant: tenant, user: user, parent: top_level) }

    it ".top_level returns only comments without a parent" do
      expect(Comment.top_level).to include(top_level)
      expect(Comment.top_level).not_to include(reply)
    end

    it ".chronological orders by created_at ascending" do
      older = create(:comment, case: rfe_case, tenant: tenant, user: user, created_at: 1.hour.ago)
      newer = create(:comment, case: rfe_case, tenant: tenant, user: user, created_at: Time.current)
      result = Comment.chronological
      expect(result.index(older)).to be < result.index(newer)
    end
  end

  describe "#author_name" do
    it "returns the user's full name" do
      comment = create(:comment, case: rfe_case, tenant: tenant, user: user)
      expect(comment.author_name).to eq(user.full_name)
    end
  end

  describe "#mentioned_users" do
    let(:mentioned_user) { create(:user, :attorney, tenant: tenant) }

    it "returns users matching mentioned_user_ids" do
      comment = create(:comment, case: rfe_case, tenant: tenant, user: user, mentioned_user_ids: [mentioned_user.id])
      expect(comment.mentioned_users).to include(mentioned_user)
    end

    it "returns empty relation when no mentions" do
      comment = create(:comment, case: rfe_case, tenant: tenant, user: user, mentioned_user_ids: [])
      expect(comment.mentioned_users).to be_empty
    end
  end

  describe "self-referential replies" do
    it "cascades deletion of replies when parent is deleted" do
      parent = create(:comment, case: rfe_case, tenant: tenant, user: user)
      create(:comment, case: rfe_case, tenant: tenant, user: user, parent: parent)
      create(:comment, case: rfe_case, tenant: tenant, user: user, parent: parent)

      expect { parent.destroy }.to change(Comment, :count).by(-3)
    end
  end
end
