class Api::V1::CommentsController < Api::V1::BaseController
  before_action :set_case
  before_action :set_comment, only: %i[update destroy]

  # GET /api/v1/cases/:case_id/comments
  def index
    authorize @case, :show?
    comments = policy_scope(Comment).where(case_id: @case.id).top_level.chronological.includes(:user, replies: :user)
    render json: { data: CommentSerializer.render_as_hash(comments) }
  end

  # POST /api/v1/cases/:case_id/comments
  def create
    @comment = @case.comments.new(comment_params)
    @comment.user = current_user
    @comment.tenant = current_user.tenant
    authorize @comment

    @comment.save!

    broadcast_comment(@comment)
    notify_mentioned_users(@comment)

    render json: { data: CommentSerializer.render_as_hash(@comment) }, status: :created
  end

  # PATCH/PUT /api/v1/cases/:case_id/comments/:id
  def update
    authorize @comment

    @comment.update!(comment_params)
    render json: { data: CommentSerializer.render_as_hash(@comment) }
  end

  # DELETE /api/v1/cases/:case_id/comments/:id
  def destroy
    authorize @comment

    @comment.destroy!
    head :no_content
  end

  private

  def set_case
    @case = RfeCase.find(params[:case_id])
  end

  def set_comment
    @comment = @case.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id, mentioned_user_ids: [])
  end

  def broadcast_comment(comment)
    CaseUpdatesChannel.broadcast_update(
      comment.tenant_id,
      type: "comment_added",
      case_id: @case.id,
      case_number: @case.case_number,
      message: "#{comment.user.full_name} commented on case #{@case.case_number}"
    )
  end

  def notify_mentioned_users(comment)
    comment.mentioned_users.each do |mentioned_user|
      next if mentioned_user.id == current_user.id

      NotificationChannel.notify(
        mentioned_user,
        type: "mention",
        title: "You were mentioned",
        body: "#{current_user.full_name} mentioned you in a comment on case #{@case.case_number}",
        data: { case_id: @case.id, comment_id: comment.id }
      )
    end
  end
end
