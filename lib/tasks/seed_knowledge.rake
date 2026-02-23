namespace :knowledge do
  desc "Seed knowledge base documents from sample_files directory"
  task seed: :environment do
    files_dir = ENV.fetch("FILES_DIR", "/rails/sample_files")

    unless Dir.exist?(files_dir)
      puts "ERROR: #{files_dir} not found. Copy sample_files into the container first."
      exit 1
    end

    tenant = Tenant.find_by!(slug: "demo-immigration-law-firm")
    admin  = User.find_by!(email: "admin@rfeready.com")

    ActsAsTenant.with_tenant(tenant) do
      docs = [
        # --- Regulations (11) ---
        { file: "8_CFR_214.2h_Specialty_Occupation.txt",                         doc_type: :regulation, visa_type: "H-1B", rfe_category: "Specialty Occupation",          title: "8 CFR 214.2(h) - Specialty Occupation Definition" },
        { file: "8_CFR_214.2h_Employer_Employee_Relationship.txt",               doc_type: :regulation, visa_type: "H-1B", rfe_category: "Employer-Employee Relationship", title: "8 CFR 214.2(h) - Employer-Employee Relationship" },
        { file: "INA_Section_101_H1B.txt",                                       doc_type: :regulation, visa_type: "H-1B", rfe_category: "Specialty Occupation",          title: "INA Section 101(a)(15)(H)(i)(b) - H-1B Classification" },
        { file: "USCIS_Policy_Memo_Specialty_Occupation_2018.txt",               doc_type: :regulation, visa_type: "H-1B", rfe_category: "Specialty Occupation",          title: "USCIS Policy Memo - Specialty Occupation (2018)" },
        { file: "USCIS_Policy_Memo_Level_1_Wages.txt",                           doc_type: :regulation, visa_type: "H-1B", rfe_category: "Wage Level",                   title: "USCIS Policy Memo - Level 1 Wage Issues" },
        { file: "O1_Extraordinary_Ability_Standards.txt",                         doc_type: :regulation, visa_type: "O-1",  rfe_category: "Extraordinary Ability",         title: "O-1 Extraordinary Ability Standards" },
        { file: "L1_Specialized_Knowledge_Standards.txt",                         doc_type: :regulation, visa_type: "L-1",  rfe_category: "Specialized Knowledge",         title: "L-1 Specialized Knowledge Standards" },
        { file: "EB1A_Extraordinary_Ability_Criteria.txt",                        doc_type: :regulation, visa_type: "EB-1", rfe_category: "Extraordinary Ability",         title: "EB-1A Extraordinary Ability Criteria" },
        { file: "Regulation_USCIS_Adjudicators_Field_Manual_Specialty_Occupation.txt", doc_type: :regulation, visa_type: "H-1B", rfe_category: "Specialty Occupation",     title: "USCIS Adjudicator's Field Manual - Specialty Occupation" },
        { file: "Regulation_Matter_of_Simeio_Solutions.txt",                      doc_type: :regulation, visa_type: "H-1B", rfe_category: "Employer-Employee Relationship", title: "Matter of Simeio Solutions - LCA Amendment" },
        { file: "Regulation_USCIS_H1B_Third_Party_Worksite.txt",                 doc_type: :regulation, visa_type: "H-1B", rfe_category: "Employer-Employee Relationship", title: "USCIS H-1B Third Party Worksite Memo" },

        # --- Templates (5) ---
        { file: "Template_RFE_Response_Cover_Letter.txt",                        doc_type: :template, visa_type: "H-1B", rfe_category: "General",                        title: "Template: RFE Response Cover Letter" },
        { file: "Template_Specialty_Occupation_Analysis.txt",                     doc_type: :template, visa_type: "H-1B", rfe_category: "Specialty Occupation",            title: "Template: Specialty Occupation Analysis" },
        { file: "Template_Beneficiary_Qualifications.txt",                        doc_type: :template, visa_type: "H-1B", rfe_category: "Beneficiary Qualifications",     title: "Template: Beneficiary Qualifications Brief" },
        { file: "Template_Employer_Employee_Relationship.txt",                    doc_type: :template, visa_type: "H-1B", rfe_category: "Employer-Employee Relationship", title: "Template: Employer-Employee Relationship Brief" },
        { file: "Template_Expert_Opinion_Letter_CS.txt",                          doc_type: :template, visa_type: "H-1B", rfe_category: "Specialty Occupation",            title: "Template: Expert Opinion Letter (Computer Science)" },
        { file: "Template_H1B_Itinerary_Requirement.txt",                        doc_type: :template, visa_type: "H-1B", rfe_category: "Itinerary",                      title: "Template: H-1B Itinerary Requirement Response" },

        # --- Sample Responses (9) ---
        { file: "Sample_Response_Specialty_Occupation_Software_Engineer.txt",     doc_type: :sample_response, visa_type: "H-1B", rfe_category: "Specialty Occupation",    title: "Sample: Specialty Occupation - Software Engineer" },
        { file: "Sample_Response_Specialty_Occupation_Financial_Analyst.txt",     doc_type: :sample_response, visa_type: "H-1B", rfe_category: "Specialty Occupation",    title: "Sample: Specialty Occupation - Financial Analyst" },
        { file: "Sample_Response_Beneficiary_Qualifications.txt",                doc_type: :sample_response, visa_type: "H-1B", rfe_category: "Beneficiary Qualifications", title: "Sample: Beneficiary Qualifications Response" },
        { file: "Sample_Response_Employer_Employee_IT_Consulting.txt",           doc_type: :sample_response, visa_type: "H-1B", rfe_category: "Employer-Employee Relationship", title: "Sample: Employer-Employee - IT Consulting" },
        { file: "Sample_Response_Maintenance_of_Status.txt",                     doc_type: :sample_response, visa_type: "H-1B", rfe_category: "Maintenance of Status",   title: "Sample: Maintenance of Status Response" },
        { file: "Sample_Response_O1_Extraordinary_Ability_Sciences.txt",         doc_type: :sample_response, visa_type: "O-1",  rfe_category: "Extraordinary Ability",    title: "Sample: O-1 Extraordinary Ability - Sciences" },
        { file: "Sample_Response_L1B_Specialized_Knowledge.txt",                 doc_type: :sample_response, visa_type: "L-1",  rfe_category: "Specialized Knowledge",    title: "Sample: L-1B Specialized Knowledge Response" },
        { file: "Sample_Response_EB2_NIW_National_Interest.txt",                 doc_type: :sample_response, visa_type: "EB-2", rfe_category: "National Interest Waiver", title: "Sample: EB-2 NIW National Interest Response" },
        { file: "Sample_Response_H1B_Wage_Level_Deficiency.txt",                 doc_type: :sample_response, visa_type: "H-1B", rfe_category: "Wage Level",               title: "Sample: H-1B Wage Level Deficiency Response" },

        # --- Firm Knowledge (7) ---
        { file: "Firm_Knowledge_H1B_RFE_Strategy_Guide.txt",                    doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "General",                   title: "H-1B RFE Strategy Guide" },
        { file: "Firm_Knowledge_Common_RFE_Issues_By_Visa_Type.txt",            doc_type: :firm_knowledge, visa_type: nil,    rfe_category: "General",                    title: "Common RFE Issues By Visa Type" },
        { file: "Firm_Knowledge_Expert_Opinion_Letter_Vendors.txt",             doc_type: :firm_knowledge, visa_type: nil,    rfe_category: "General",                    title: "Expert Opinion Letter Vendors" },
        { file: "Firm_Knowledge_Evidence_Checklist_H1B.txt",                    doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "General",                    title: "Evidence Checklist - H-1B" },
        { file: "Firm_Knowledge_Client_Communication_Templates.txt",            doc_type: :firm_knowledge, visa_type: nil,    rfe_category: "General",                    title: "Client Communication Templates" },
        { file: "Firm_Knowledge_AAO_Decision_Summaries.txt",                    doc_type: :firm_knowledge, visa_type: nil,    rfe_category: "General",                    title: "AAO Decision Summaries" },
        { file: "Firm_Knowledge_EB2_NIW_Dhanasar_Framework.txt",               doc_type: :firm_knowledge, visa_type: "EB-2", rfe_category: "National Interest Waiver",   title: "EB-2 NIW Dhanasar Framework Guide" },

        # --- Supporting Evidence (7, stored as firm_knowledge) ---
        { file: "RFE_Notice_Sample.txt",              doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "General",                        title: "RFE Notice - Sample H-1B" },
        { file: "Expert_Opinion_Letter.txt",           doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "Specialty Occupation",            title: "Expert Opinion Letter - Sample" },
        { file: "Support_Letter_Employer.txt",         doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "Employer-Employee Relationship", title: "Employer Support Letter - Sample" },
        { file: "Detailed_Job_Description.txt",        doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "Specialty Occupation",            title: "Detailed Job Description - Software Engineer" },
        { file: "Academic_Transcripts.txt",            doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "Beneficiary Qualifications",     title: "Academic Transcripts - Sample" },
        { file: "Work_Experience_Letters.txt",         doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "Beneficiary Qualifications",     title: "Work Experience Letters - Sample" },
        { file: "Industry_Job_Postings.txt",           doc_type: :firm_knowledge, visa_type: "H-1B", rfe_category: "Specialty Occupation",            title: "Industry Job Postings - Software Engineering" },
      ]

      created = 0
      skipped = 0

      docs.each do |doc_info|
        file_path = File.join(files_dir, doc_info[:file])
        unless File.exist?(file_path)
          puts "  SKIP (missing): #{doc_info[:file]}"
          skipped += 1
          next
        end

        existing = KnowledgeDoc.find_by(title: doc_info[:title])
        if existing
          puts "  EXISTS: #{doc_info[:title]}"
          skipped += 1
          next
        end

        content = File.read(file_path)
        kd = KnowledgeDoc.new(
          title: doc_info[:title],
          doc_type: doc_info[:doc_type],
          visa_type: doc_info[:visa_type],
          rfe_category: doc_info[:rfe_category],
          content: content,
          uploaded_by: admin,
          is_active: true
        )
        kd.file.attach(
          io: File.open(file_path),
          filename: doc_info[:file],
          content_type: "text/plain"
        )
        kd.save!
        puts "  CREATED: #{doc_info[:title]}"
        created += 1
      end

      puts "\n✅ Knowledge base seeded: #{created} created, #{skipped} skipped"

      # Generate embeddings
      pending = KnowledgeDoc.left_joins(:embeddings).where(embeddings: { id: nil })
      count = pending.count
      if count > 0
        puts "\nGenerating embeddings for #{count} documents..."
        pending.find_each.with_index do |doc, i|
          print "  [#{i + 1}/#{count}] #{doc.title}... "
          begin
            EmbeddingService.new(doc).generate
            puts "done (#{doc.embeddings.count} chunks)"
          rescue => e
            puts "ERROR: #{e.message}"
          end
        end
        puts "\n✅ Embedding generation complete!"
      else
        puts "\nAll documents already have embeddings."
      end
    end
  end
end
