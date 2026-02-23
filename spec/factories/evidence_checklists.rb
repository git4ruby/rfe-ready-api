FactoryBot.define do
  factory :evidence_checklist do
    tenant
    association :case, factory: :rfe_case
    rfe_section
    document_name { Faker::Lorem.sentence(word_count: 3) }
    sequence(:position) { |n| n }
    priority { :required }
    is_collected { false }

    trait :collected do
      is_collected { true }
    end

    trait :optional do
      priority { :optional }
    end

    trait :recommended do
      priority { :recommended }
    end
  end
end
