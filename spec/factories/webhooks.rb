FactoryBot.define do
  factory :webhook do
    tenant
    url { "https://example.com/webhooks/receive" }
    events { ["case.created"] }
    secret { "test_secret_key" }
    active { true }
    description { "Test webhook" }

    trait :inactive do
      active { false }
    end

    trait :without_secret do
      secret { nil }
    end

    trait :multiple_events do
      events { ["case.created", "case.updated", "document.uploaded"] }
    end
  end
end
