require "rails_helper"

RSpec.describe ReportingService, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :admin, tenant: tenant) }
  let(:attorney) { create(:user, :attorney, tenant: tenant) }

  before { ActsAsTenant.current_tenant = tenant }

  describe "#call" do
    subject(:result) { described_class.new(tenant: tenant, period: "all").call }

    context "with case stats" do
      before do
        create(:rfe_case, tenant: tenant, created_by: user, visa_type: "H-1B", status: "draft")
        create(:rfe_case, tenant: tenant, created_by: user, visa_type: "H-1B", status: "review")
        create(:rfe_case, tenant: tenant, created_by: user, visa_type: "L-1", status: "responded")
      end

      it "returns total case count" do
        expect(result[:case_stats][:total]).to eq(3)
      end

      it "groups cases by status" do
        by_status = result[:case_stats][:by_status]
        expect(by_status["draft"]).to eq(1)
        expect(by_status["review"]).to eq(1)
        expect(by_status["responded"]).to eq(1)
      end

      it "groups cases by visa type" do
        by_visa = result[:case_stats][:by_visa_type]
        expect(by_visa["H-1B"]).to eq(2)
        expect(by_visa["L-1"]).to eq(1)
      end

      it "calculates completion rate" do
        # 1 responded out of 3 total = 33.3%
        expect(result[:case_stats][:completion_rate]).to eq(33.3)
      end
    end

    context "with avg_days_to_respond calculation" do
      it "calculates average days correctly" do
        travel_to Time.zone.local(2024, 1, 1) do
          c1 = create(:rfe_case, tenant: tenant, created_by: user, status: "responded")
          c1.update_column(:updated_at, Time.zone.local(2024, 1, 11)) # 10 days later

          c2 = create(:rfe_case, tenant: tenant, created_by: user, status: "responded")
          c2.update_column(:updated_at, Time.zone.local(2024, 1, 21)) # 20 days later

          svc_result = described_class.new(tenant: tenant, period: "all").call
          expect(svc_result[:case_stats][:avg_days_to_respond]).to eq(15.0)
        end
      end

      it "returns 0.0 when no responded cases exist" do
        create(:rfe_case, tenant: tenant, created_by: user, status: "draft")
        svc_result = described_class.new(tenant: tenant, period: "all").call
        expect(svc_result[:case_stats][:avg_days_to_respond]).to eq(0.0)
      end
    end

    context "with timeline data" do
      it "returns cases created over time grouped by date" do
        travel_to Time.zone.local(2024, 3, 1) do
          create(:rfe_case, tenant: tenant, created_by: user)
        end
        travel_to Time.zone.local(2024, 3, 2) do
          create_list(:rfe_case, 2, tenant: tenant, created_by: user)
        end

        svc_result = described_class.new(tenant: tenant, period: "all").call
        timeline = svc_result[:timeline][:cases_created_over_time]

        expect(timeline["2024-03-01"]).to eq(1)
        expect(timeline["2024-03-02"]).to eq(2)
      end

      it "returns cases responded over time grouped by date" do
        c1 = create(:rfe_case, tenant: tenant, created_by: user, status: "responded")
        c1.update_column(:updated_at, Time.zone.local(2024, 4, 10))

        c2 = create(:rfe_case, tenant: tenant, created_by: user, status: "responded")
        c2.update_column(:updated_at, Time.zone.local(2024, 4, 10))

        svc_result = described_class.new(tenant: tenant, period: "all").call
        responded_timeline = svc_result[:timeline][:cases_responded_over_time]

        expect(responded_timeline["2024-04-10"]).to eq(2)
      end
    end

    context "with evidence collection stats" do
      let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
      let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }

      before do
        create_list(:evidence_checklist, 3, tenant: tenant, case: rfe_case, rfe_section: section, is_collected: false)
        create_list(:evidence_checklist, 2, :collected, tenant: tenant, case: rfe_case, rfe_section: section)
      end

      it "returns total checklist items" do
        expect(result[:evidence_stats][:total_checklist_items]).to eq(5)
      end

      it "returns collected count" do
        expect(result[:evidence_stats][:collected_count]).to eq(2)
      end

      it "calculates collection rate" do
        expect(result[:evidence_stats][:collection_rate]).to eq(40.0)
      end
    end

    context "with draft approval stats" do
      let(:rfe_case) { create(:rfe_case, tenant: tenant, created_by: user) }
      let(:section) { create(:rfe_section, tenant: tenant, case: rfe_case) }

      before do
        create_list(:draft_response, 3, tenant: tenant, case: rfe_case, rfe_section: section, status: :draft)
        create_list(:draft_response, 2, :approved, tenant: tenant, case: rfe_case, rfe_section: section)
      end

      it "returns total drafts" do
        expect(result[:draft_stats][:total_drafts]).to eq(5)
      end

      it "returns approved count" do
        expect(result[:draft_stats][:approved_count]).to eq(2)
      end

      it "calculates approval rate" do
        expect(result[:draft_stats][:approval_rate]).to eq(40.0)
      end
    end

    context "with attorney performance stats" do
      let(:attorney2) { create(:user, :attorney, tenant: tenant) }

      before do
        c1 = create(:rfe_case, tenant: tenant, created_by: user, assigned_attorney: attorney, status: "responded")
        c1.update_column(:updated_at, c1.created_at + 10.days)

        c2 = create(:rfe_case, tenant: tenant, created_by: user, assigned_attorney: attorney, status: "responded")
        c2.update_column(:updated_at, c2.created_at + 20.days)

        create(:rfe_case, tenant: tenant, created_by: user, assigned_attorney: attorney2, status: "review")
      end

      it "returns stats for each attorney" do
        stats = result[:attorney_stats]
        expect(stats.length).to eq(2)
      end

      it "includes attorney details" do
        stats = result[:attorney_stats]
        atty_stat = stats.find { |s| s[:attorney_id] == attorney.id }

        expect(atty_stat[:attorney_name]).to eq(attorney.full_name)
        expect(atty_stat[:case_count]).to eq(2)
        expect(atty_stat[:avg_resolution_days]).to eq(15.0)
      end

      it "returns 0 avg_resolution_days for attorneys with no responded cases" do
        stats = result[:attorney_stats]
        atty2_stat = stats.find { |s| s[:attorney_id] == attorney2.id }

        expect(atty2_stat[:case_count]).to eq(1)
        expect(atty2_stat[:avg_resolution_days]).to eq(0.0)
      end
    end

    context "with empty data" do
      it "handles no cases gracefully" do
        expect(result[:case_stats][:total]).to eq(0)
        expect(result[:case_stats][:by_status]).to eq({})
        expect(result[:case_stats][:by_visa_type]).to eq({})
        expect(result[:case_stats][:avg_days_to_respond]).to eq(0.0)
        expect(result[:case_stats][:completion_rate]).to eq(0.0)
      end

      it "handles no evidence checklists gracefully" do
        expect(result[:evidence_stats][:total_checklist_items]).to eq(0)
        expect(result[:evidence_stats][:collected_count]).to eq(0)
        expect(result[:evidence_stats][:collection_rate]).to eq(0.0)
      end

      it "handles no drafts gracefully" do
        expect(result[:draft_stats][:total_drafts]).to eq(0)
        expect(result[:draft_stats][:approved_count]).to eq(0)
        expect(result[:draft_stats][:approval_rate]).to eq(0.0)
      end

      it "handles no attorneys gracefully" do
        expect(result[:attorney_stats]).to eq([])
      end

      it "returns empty timeline" do
        expect(result[:timeline][:cases_created_over_time]).to eq({})
        expect(result[:timeline][:cases_responded_over_time]).to eq({})
      end
    end

    context "with period filtering" do
      it "filters cases within 7d period" do
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 3.days.ago)
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 20.days.ago)

        svc_result = described_class.new(tenant: tenant, period: "7d").call
        expect(svc_result[:case_stats][:total]).to eq(1)
      end

      it "filters cases within 30d period" do
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 10.days.ago)
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 60.days.ago)

        svc_result = described_class.new(tenant: tenant, period: "30d").call
        expect(svc_result[:case_stats][:total]).to eq(1)
      end

      it "filters cases within 90d period" do
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 30.days.ago)
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 120.days.ago)

        svc_result = described_class.new(tenant: tenant, period: "90d").call
        expect(svc_result[:case_stats][:total]).to eq(1)
      end

      it "returns all cases with 'all' period" do
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 1.year.ago)
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 1.day.ago)

        svc_result = described_class.new(tenant: tenant, period: "all").call
        expect(svc_result[:case_stats][:total]).to eq(2)
      end

      it "defaults to 30d for unknown period values" do
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 10.days.ago)
        create(:rfe_case, tenant: tenant, created_by: user, created_at: 60.days.ago)

        svc_result = described_class.new(tenant: tenant, period: "unknown").call
        expect(svc_result[:case_stats][:total]).to eq(1)
      end
    end
  end
end
