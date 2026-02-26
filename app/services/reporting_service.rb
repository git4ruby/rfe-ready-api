class ReportingService
  def initialize(tenant:, period: "30d")
    @tenant = tenant
    @period = period
    @range = build_range(period)
  end

  def call
    {
      case_stats: case_stats,
      timeline: timeline,
      evidence_stats: evidence_stats,
      draft_stats: draft_stats,
      attorney_stats: attorney_stats
    }
  end

  private

  attr_reader :tenant, :period, :range

  # ── Period helpers ──────────────────────────────────────────────

  def build_range(period)
    case period
    when "7d"  then 7.days.ago..Time.current
    when "90d" then 90.days.ago..Time.current
    when "all" then nil
    else 30.days.ago..Time.current
    end
  end

  def scoped_cases
    scope = RfeCase.where(tenant: tenant)
    range ? scope.where(created_at: range) : scope
  end

  # ── Case stats ──────────────────────────────────────────────────

  def case_stats
    cases = scoped_cases
    total = cases.count
    responded_count = cases.where(status: "responded").count

    {
      total: total,
      by_status: cases.group(:status).count,
      by_visa_type: cases.group(:visa_type).count,
      avg_days_to_respond: avg_days_to_respond(cases),
      completion_rate: total.zero? ? 0.0 : (responded_count.to_f / total * 100).round(1)
    }
  end

  def avg_days_to_respond(cases)
    responded = cases.where(status: "responded")
    return 0.0 if responded.none?

    total_days = responded.sum do |c|
      (c.updated_at.to_date - c.created_at.to_date).to_f
    end

    (total_days / responded.count).round(1)
  end

  # ── Timeline ────────────────────────────────────────────────────

  def timeline
    cases = scoped_cases

    {
      cases_created_over_time: cases.group("DATE(created_at)").count.transform_keys(&:to_s),
      cases_responded_over_time: cases.where(status: "responded")
                                      .group("DATE(updated_at)").count.transform_keys(&:to_s)
    }
  end

  # ── Evidence stats ──────────────────────────────────────────────

  def evidence_stats
    case_ids = scoped_cases.pluck(:id)
    checklists = EvidenceChecklist.where(case_id: case_ids)
    total = checklists.count
    collected = checklists.where(is_collected: true).count

    {
      total_checklist_items: total,
      collected_count: collected,
      collection_rate: total.zero? ? 0.0 : (collected.to_f / total * 100).round(1)
    }
  end

  # ── Draft stats ─────────────────────────────────────────────────

  def draft_stats
    case_ids = scoped_cases.pluck(:id)
    drafts = DraftResponse.where(case_id: case_ids)
    total = drafts.count
    approved = drafts.where(status: :approved).count

    {
      total_drafts: total,
      approved_count: approved,
      approval_rate: total.zero? ? 0.0 : (approved.to_f / total * 100).round(1)
    }
  end

  # ── Attorney stats ─────────────────────────────────────────────

  def attorney_stats
    cases = scoped_cases.where.not(assigned_attorney_id: nil).includes(:assigned_attorney)

    cases.group_by(&:assigned_attorney).map do |attorney, attorney_cases|
      responded = attorney_cases.select { |c| c.status == "responded" }
      avg_days = if responded.any?
        total = responded.sum { |c| (c.updated_at.to_date - c.created_at.to_date).to_f }
        (total / responded.size).round(1)
      else
        0.0
      end

      {
        attorney_id: attorney.id,
        attorney_name: attorney.full_name,
        case_count: attorney_cases.size,
        avg_resolution_days: avg_days
      }
    end
  end
end
