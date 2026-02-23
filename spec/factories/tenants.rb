FactoryBot.define do
  factory :tenant do
    name { Faker::Company.name }
    sequence(:slug) { |n| "tenant-#{n}" }
    plan { :trial }
    status { :active }

    trait :trial do
      plan { :trial }
    end

    trait :basic do
      plan { :basic }
    end

    trait :professional do
      plan { :professional }
    end

    trait :enterprise do
      plan { :enterprise }
    end

    trait :suspended do
      status { :suspended }
    end

    trait :platform do
      name { "Platform Admin" }
      slug { Tenant::PLATFORM_SLUG }
    end
  end
end
