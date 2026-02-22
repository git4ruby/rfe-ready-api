class Api::V1::DashboardController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /api/v1/dashboard
  def index
    period = params[:period] || "30d"
    range = case period
            when "7d" then 7.days.ago..Time.current
            when "90d" then 90.days.ago..Time.current
            when "all" then nil
            else 30.days.ago..Time.current
            end

    cases = RfeCase.where(tenant: current_user.tenant)
    knowledge_docs = KnowledgeDoc.where(tenant: current_user.tenant)

    # Knowledge base stats
    embedded_ids = Embedding.where(tenant: current_user.tenant, embeddable_type: "KnowledgeDoc")
                            .distinct.pluck(:embeddable_id)

    render json: {
      data: {
        total_cases: cases.count,
        cases_by_status: cases.group(:status).count,
        cases_by_visa_type: cases.group(:visa_type).count,
        approaching_deadlines: cases.approaching_deadline.count,
        recent_cases: CaseSerializer.render_as_hash(
          cases.order(created_at: :desc).limit(5)
        ),
        knowledge_stats: {
          total_docs: knowledge_docs.count,
          by_doc_type: knowledge_docs.group(:doc_type).count,
          by_visa_type: knowledge_docs.where.not(visa_type: [nil, ""]).group(:visa_type).count,
          embedded_count: embedded_ids.size,
          pending_count: knowledge_docs.count - embedded_ids.size
        },
        recent_activity: AuditLogSerializer.render_as_hash(
          AuditLog.where(tenant: current_user.tenant).recent.limit(5).includes(:user)
        ),
        cases_over_time: build_cases_over_time(cases, range)
      }
    }
  end

  private

  def build_cases_over_time(cases, range)
    scope = range ? cases.where(created_at: range) : cases
    scope.group("DATE(created_at)").count.transform_keys(&:to_s)
  end
end
