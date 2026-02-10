class RfeCasePolicy < ApplicationPolicy
  def show?
    true
  end

  def create?
    can_edit?
  end

  def update?
    can_edit?
  end

  def start_analysis?
    can_edit?
  end

  def assign_attorney?
    attorney?
  end

  def mark_reviewed?
    attorney?
  end

  def mark_responded?
    attorney?
  end

  def export?
    attorney?
  end

  def archive?
    can_edit?
  end

  def reopen?
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
