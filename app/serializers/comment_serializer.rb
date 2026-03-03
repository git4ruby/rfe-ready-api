class CommentSerializer < Blueprinter::Base
  identifier :id
  fields :body, :parent_id, :mentioned_user_ids, :created_at, :updated_at

  field :user_name do |comment|
    comment.user.full_name
  end

  field :user_id do |comment|
    comment.user_id
  end

  association :replies, blueprint: CommentSerializer do |comment|
    comment.replies.chronological
  end
end
