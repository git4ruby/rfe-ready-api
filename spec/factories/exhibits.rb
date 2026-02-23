FactoryBot.define do
  factory :exhibit do
    tenant
    association :case, factory: :rfe_case
    sequence(:label) { |n| "Exhibit #{('A'.ord + n - 1).chr}" }
    title { Faker::Lorem.sentence(word_count: 3) }
    sequence(:position) { |n| n }
  end
end
