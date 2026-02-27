FactoryBot.define do
  factory :slack_integration do
    tenant
    webhook_url { "https://hooks.slack.com/services/T00/B00/xxxx" }
    channel_name { "#general" }
    events { ["case.created"] }
    active { true }

    trait :inactive do
      active { false }
    end
  end
end
