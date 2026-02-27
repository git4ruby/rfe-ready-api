class CaseTemplatePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    can_edit?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
