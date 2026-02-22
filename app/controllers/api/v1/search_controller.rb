class Api::V1::SearchController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /api/v1/search?q=term
  def index
    q = params[:q].to_s.strip
    if q.blank? || q.length < 2
      render json: { data: { cases: [], knowledge_docs: [], users: [] } }
      return
    end

    term = "%#{q}%"

    cases = RfeCase.where(tenant: current_user.tenant)
                   .where("case_number ILIKE :t OR petitioner_name ILIKE :t OR visa_type ILIKE :t OR notes ILIKE :t", t: term)
                   .order(created_at: :desc)
                   .limit(5)

    knowledge_docs = KnowledgeDoc.where(tenant: current_user.tenant)
                                 .where("title ILIKE :t OR content ILIKE :t", t: term)
                                 .order(created_at: :desc)
                                 .limit(5)

    users = User.where(tenant: current_user.tenant)
                .where("first_name ILIKE :t OR last_name ILIKE :t OR email ILIKE :t", t: term)
                .limit(5)

    render json: {
      data: {
        cases: cases.map { |c| { id: c.id, case_number: c.case_number, petitioner_name: c.petitioner_name, visa_type: c.visa_type, status: c.status } },
        knowledge_docs: knowledge_docs.map { |d| { id: d.id, title: d.title, doc_type: d.doc_type } },
        users: users.map { |u| { id: u.id, name: u.full_name, email: u.email, role: u.role } }
      }
    }
  end
end
