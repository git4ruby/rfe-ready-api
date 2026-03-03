require "rails_helper"

RSpec.describe "Draft Response Locking", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }
  let(:other_attorney) { create(:user, :attorney, tenant: tenant) }
  let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: admin) }
  let(:section) { create(:rfe_section, case: rfe_case, tenant: tenant) }
  let!(:draft) { create(:draft_response, case: rfe_case, rfe_section: section, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "POST /api/v1/cases/:case_id/draft_responses/:id/lock" do
    it "locks the draft for the current user" do
      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/lock",
        headers: auth_headers(attorney), as: :json

      expect(response).to have_http_status(:ok)
      draft.reload
      expect(draft.locked_by_id).to eq(attorney.id)
      expect(draft.locked_at).to be_present
    end

    it "returns conflict when another user holds the lock" do
      draft.update!(locked_by: other_attorney, locked_at: Time.current)

      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/lock",
        headers: auth_headers(attorney), as: :json

      expect(response).to have_http_status(:conflict)
    end

    it "allows lock takeover when lock is stale (older than 5 min)" do
      draft.update!(locked_by: other_attorney, locked_at: 10.minutes.ago)

      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/lock",
        headers: auth_headers(attorney), as: :json

      expect(response).to have_http_status(:ok)
      draft.reload
      expect(draft.locked_by_id).to eq(attorney.id)
    end

    it "returns 401 without auth" do
      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/lock"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/cases/:case_id/draft_responses/:id/unlock" do
    before { draft.update!(locked_by: attorney, locked_at: Time.current) }

    it "unlocks the draft for the lock holder" do
      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/unlock",
        headers: auth_headers(attorney), as: :json

      expect(response).to have_http_status(:ok)
      draft.reload
      expect(draft.locked_by_id).to be_nil
      expect(draft.locked_at).to be_nil
    end

    it "admin can unlock any draft" do
      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/unlock",
        headers: auth_headers(admin), as: :json

      expect(response).to have_http_status(:ok)
      draft.reload
      expect(draft.locked_by_id).to be_nil
    end

    it "non-holder cannot unlock" do
      post "/api/v1/cases/#{rfe_case.id}/draft_responses/#{draft.id}/unlock",
        headers: auth_headers(other_attorney), as: :json

      expect(response).to have_http_status(:ok)
      draft.reload
      # Lock should still be held since other_attorney is not admin and not the lock holder
      expect(draft.locked_by_id).to eq(attorney.id)
    end
  end
end
