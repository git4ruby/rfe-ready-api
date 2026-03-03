FactoryBot.define do
  factory :comment do
    tenant
    association :case, factory: :rfe_case
    user
    body { Faker::Lorem.paragraph }
  end
end
