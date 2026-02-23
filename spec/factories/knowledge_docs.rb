FactoryBot.define do
  factory :knowledge_doc do
    tenant
    association :uploaded_by, factory: :user
    title { Faker::Lorem.sentence(word_count: 4) }
    doc_type { :regulation }
    content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    is_active { true }

    trait :template do
      doc_type { :template }
    end

    trait :sample_response do
      doc_type { :sample_response }
    end

    trait :regulation do
      doc_type { :regulation }
    end

    trait :firm_knowledge do
      doc_type { :firm_knowledge }
    end

    trait :inactive do
      is_active { false }
    end

    trait :with_visa_type do
      visa_type { "H-1B" }
    end
  end
end
