class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    same_tenant?
  end

  def create?
    admin?
  end

  def update?
    admin? && same_tenant? && !self_target?
  end

  def destroy?
    admin? && same_tenant? && !self_target?
  end

  def resend_invitation?
    admin? && same_tenant?
  end

  private

  def same_tenant?
    record.tenant_id == user.tenant_id
  end

  def self_target?
    record.id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(tenant_id: user.tenant_id)
    end
  end
end
