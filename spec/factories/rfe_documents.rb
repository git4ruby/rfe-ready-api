FactoryBot.define do
  factory :rfe_document do
    tenant
    association :case, factory: :rfe_case
    association :uploaded_by, factory: :user
    filename { "rfe_notice.pdf" }
    document_type { :rfe_notice }
    processing_status { :pending }
    content_type { "application/pdf" }
    file_size { 1024 }

    trait :rfe_notice do
      document_type { :rfe_notice }
    end

    trait :supporting_evidence do
      document_type { :supporting_evidence }
    end

    trait :processed do
      processing_status { :completed }
      extracted_text { "Sample extracted text from the RFE notice document." }
    end

    trait :failed do
      processing_status { :failed }
    end
  end
end
