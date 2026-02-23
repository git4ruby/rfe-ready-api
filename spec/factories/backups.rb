FactoryBot.define do
  factory :backup do
    tenant
    user
    status { :pending }

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      file_url { "/backups/backup-#{SecureRandom.hex(4)}.json" }
      file_size { 7500 }
      completed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      error_message { "Backup failed due to timeout" }
    end
  end
end
