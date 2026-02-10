class RfeDocumentPolicy < ApplicationPolicy
  def show?
    true
  end

  def create?
    can_edit?
  end

  def destroy?
    admin? || record.uploaded_by_id == user.id
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
