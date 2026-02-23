FactoryBot.define do
  factory :feature_flag do
    tenant
    sequence(:name) { |n| "feature_#{n}" }
    enabled { true }
    allowed_roles { [] }
    allowed_plans { [] }

    trait :disabled do
      enabled { false }
    end

    trait :admin_only do
      allowed_roles { %w[admin] }
    end

    trait :professional_only do
      allowed_plans { %w[professional enterprise] }
    end
  end
end
