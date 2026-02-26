class Comment < ApplicationRecord
  include Auditable

  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :case, class_name: "RfeCase"
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true

  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true

  scope :top_level, -> { where(parent_id: nil) }
  scope :chronological, -> { order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }

  def author_name
    user.full_name
  end

  def mentioned_users
    return User.none if mentioned_user_ids.blank?

    User.where(id: mentioned_user_ids)
  end
end
