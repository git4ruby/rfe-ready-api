FactoryBot.define do
  factory :user do
    tenant
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password123!" }
    role { :admin }
    status { :active }
    confirmed_at { Time.current }
    jti { SecureRandom.uuid }

    trait :admin do
      role { :admin }
    end

    trait :attorney do
      role { :attorney }
      bar_number { Faker::Number.number(digits: 7).to_s }
    end

    trait :paralegal do
      role { :paralegal }
    end

    trait :viewer do
      role { :viewer }
    end

    trait :super_admin do
      is_super_admin { true }
    end

    trait :inactive do
      status { :inactive }
    end

    trait :invited do
      status { :invited }
      confirmed_at { nil }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end
