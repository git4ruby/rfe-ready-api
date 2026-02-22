class Api::V1::BackupsController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :require_admin

  # GET /api/v1/backups
  def index
    backups = Backup.where(tenant: current_user.tenant).recent.limit(20)
    render json: { data: BackupSerializer.render_as_hash(backups) }
  end

  # POST /api/v1/backups
  def create
    backup = Backup.create!(
      tenant: current_user.tenant,
      user: current_user,
      status: :pending
    )

    TenantBackupJob.perform_later(backup.id)

    render json: { data: BackupSerializer.render_as_hash(backup) }, status: :created
  end

  # DELETE /api/v1/backups/:id
  def destroy
    backup = Backup.where(tenant: current_user.tenant).find(params[:id])
    backup.destroy!
    render json: { meta: { message: "Backup deleted." } }
  end

  # GET /api/v1/backups/:id/download
  def download
    backup = Backup.where(tenant: current_user.tenant).find(params[:id])

    unless backup.completed?
      render json: { error: "Backup is not ready for download." }, status: :unprocessable_entity
      return
    end

    # Regenerate data for download
    tenant = current_user.tenant
    ActsAsTenant.current_tenant = tenant

    data = {
      exported_at: backup.completed_at&.iso8601,
      tenant: { name: tenant.name, slug: tenant.slug, plan: tenant.plan },
      cases: tenant.rfe_cases.map { |c|
        { case_number: c.case_number, petitioner_name: c.petitioner_name,
          beneficiary_name: c.beneficiary_name, visa_type: c.visa_type,
          status: c.status, rfe_deadline: c.rfe_deadline, notes: c.notes,
          created_at: c.created_at }
      },
      knowledge_docs: tenant.knowledge_docs.map { |d|
        { title: d.title, doc_type: d.doc_type, visa_type: d.visa_type, created_at: d.created_at }
      },
      users: tenant.users.map { |u|
        { email: u.email, name: u.full_name, role: u.role, status: u.status }
      }
    }

    send_data JSON.pretty_generate(data),
      filename: "backup-#{tenant.slug}-#{backup.completed_at&.strftime('%Y%m%d')}.json",
      type: "application/json",
      disposition: "attachment"
  end

  private

  def require_admin
    unless current_user.admin?
      render json: { error: "Only admins can manage backups." }, status: :forbidden
    end
  end
end
