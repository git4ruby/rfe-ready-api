class Api::V1::AuditLogsController < Api::V1::BaseController
  include Pagy::Backend

  # GET /api/v1/audit_logs
  def index
    authorize AuditLog

    scope = policy_scope(AuditLog).recent.includes(:user, :auditable)

    scope = scope.by_action(params[:action_type]) if params[:action_type].present?
    scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

    @pagy, logs = pagy(scope, items: 20)
    render json: {
      data: AuditLogSerializer.render_as_hash(logs),
      meta: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/audit_logs/export
  def export
    authorize AuditLog, :index?

    scope = policy_scope(AuditLog).recent.includes(:user, :auditable)
    scope = scope.by_action(params[:action_type]) if params[:action_type].present?
    scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
    logs = scope.limit(5000)

    case params[:format_type]
    when "pdf"
      send_data generate_pdf(logs),
        filename: "audit-log-#{Date.current}.pdf",
        type: "application/pdf",
        disposition: "attachment"
    else
      send_data generate_csv(logs),
        filename: "audit-log-#{Date.current}.csv",
        type: "text/csv",
        disposition: "attachment"
    end
  end

  private

  def generate_csv(logs)
    require "csv"
    CSV.generate do |csv|
      csv << ["Date/Time", "User", "Email", "Action", "Resource Type", "Resource", "IP Address", "Changes"]
      logs.each do |log|
        changes = log.changes_data&.map { |k, v| "#{k}: #{v[0]} → #{v[1]}" }&.join("; ") || ""
        csv << [
          log.created_at&.strftime("%Y-%m-%d %H:%M:%S"),
          log.user&.full_name || "System",
          log.user&.email || "",
          log.action,
          log.auditable_type,
          auditable_name_for(log),
          log.ip_address || "",
          changes
        ]
      end
    end
  end

  def generate_pdf(logs)
    pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape)
    pdf.text "Audit Log Export", size: 18, style: :bold
    pdf.text "Generated: #{Time.current.strftime('%B %d, %Y %I:%M %p')}", size: 10, color: "666666"
    pdf.move_down 15

    table_data = [["Date/Time", "User", "Action", "Resource", "IP Address"]]
    logs.each do |log|
      table_data << [
        log.created_at&.strftime("%m/%d/%Y %I:%M %p") || "",
        log.user&.full_name || "System",
        log.action&.capitalize || "",
        "#{log.auditable_type} - #{auditable_name_for(log)}",
        log.ip_address || ""
      ]
    end

    pdf.table(table_data, header: true, width: pdf.bounds.width, cell_style: { size: 8, padding: [4, 6] }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "f3f4f6"
    end

    pdf.render
  end

  def auditable_name_for(log)
    case log.auditable_type
    when "RfeCase" then log.auditable&.case_number
    when "KnowledgeDoc" then log.auditable&.title
    when "User" then log.auditable&.email
    when "DraftResponse" then "Draft ##{log.auditable&.position}"
    else log.auditable_type
    end
  rescue
    log.auditable_type
  end
end
