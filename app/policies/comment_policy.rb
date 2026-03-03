class CommentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    can_edit?
  end

  def update?
    author_or_admin?
  end

  def destroy?
    author_or_admin?
  end

  private

  def author_or_admin?
    user.admin? || record.user_id == user.id
  end
end
