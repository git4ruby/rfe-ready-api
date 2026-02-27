FactoryBot.define do
  factory :case_template do
    tenant
    sequence(:name) { |n| "Template #{n}" }
    description { "A template for common RFE cases" }
    visa_category { "H-1B" }
    default_sections { [{ "title" => "Specialty Occupation", "description" => "Evidence for specialty occupation" }, { "title" => "Beneficiary Qualifications", "description" => "Education and experience evidence" }] }
    default_checklist { [{ "item" => "Degree evaluation", "required" => true }, { "item" => "Expert opinion letter", "required" => false }] }
    default_notes { "Standard RFE response template" }
  end
end
