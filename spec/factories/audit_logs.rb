FactoryBot.define do
  factory :audit_log do
    tenant
    user
    action { "create" }
    association :auditable, factory: :rfe_case
    changes_data { {} }

    trait :update_action do
      action { "update" }
      changes_data { { "status" => %w[draft review] } }
    end

    trait :destroy_action do
      action { "destroy" }
    end
  end
end
