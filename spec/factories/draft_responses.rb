FactoryBot.define do
  factory :draft_response do
    tenant
    association :case, factory: :rfe_case
    rfe_section
    sequence(:position) { |n| n }
    title { "Draft Response" }
    ai_generated_content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    status { :draft }

    trait :editing do
      status { :editing }
      edited_content { "Edited: #{Faker::Lorem.paragraph}" }
    end

    trait :approved do
      status { :approved }
      edited_content { "Final edited content" }
      final_content { "Final edited content" }
      attorney_feedback { "Looks good" }
    end
  end
end
