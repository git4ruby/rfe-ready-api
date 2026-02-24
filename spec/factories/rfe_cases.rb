FactoryBot.define do
  factory :rfe_case do
    tenant
    association :created_by, factory: :user
    sequence(:case_number) { |n| "RFE-2024-#{n.to_s.rjust(4, '0')}" }
    visa_type { "H-1B" }
    petitioner_name { Faker::Company.name }
    beneficiary_name { Faker::Name.name }
    status { "draft" }

    trait :draft do
      status { "draft" }
    end

    trait :analyzing do
      status { "analyzing" }
    end

    trait :review do
      status { "review" }
    end

    trait :responded do
      status { "responded" }
    end

    trait :archived do
      status { "archived" }
    end

    trait :with_deadline do
      rfe_deadline { 30.days.from_now }
    end

    trait :approaching_deadline do
      rfe_deadline { 7.days.from_now }
    end

    trait :overdue do
      rfe_deadline { 3.days.ago }
    end

    trait :with_attorney do
      association :assigned_attorney, factory: [ :user, :attorney ]
    end
  end
end
