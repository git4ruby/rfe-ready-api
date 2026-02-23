FactoryBot.define do
  factory :rfe_section do
    tenant
    association :case, factory: :rfe_case
    section_type { :general }
    sequence(:position) { |n| n }
    title { "RFE Section" }
    original_text { Faker::Lorem.paragraph }
    confidence_score { 0.85 }

    trait :specialty_occupation do
      section_type { :specialty_occupation }
    end

    trait :high_confidence do
      confidence_score { 0.95 }
    end

    trait :low_confidence do
      confidence_score { 0.5 }
    end
  end
end
