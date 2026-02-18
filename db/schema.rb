# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_17_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "vector"

  create_table "active_storage_attachments", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "user_id"
    t.string "action", null: false
    t.string "auditable_type", null: false
    t.uuid "auditable_id", null: false
    t.jsonb "changes_data", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["tenant_id", "created_at"], name: "index_audit_logs_on_tenant_id_and_created_at"
    t.index ["tenant_id"], name: "index_audit_logs_on_tenant_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "cases", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "created_by_id", null: false
    t.uuid "assigned_attorney_id"
    t.string "case_number", null: false
    t.string "uscis_receipt_number"
    t.string "visa_type", default: "H-1B", null: false
    t.string "status", default: "draft", null: false
    t.string "petitioner_name"
    t.text "beneficiary_name_ciphertext"
    t.string "beneficiary_name_bidx"
    t.date "rfe_received_date"
    t.date "rfe_deadline"
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.boolean "attorney_reviewed", default: false
    t.datetime "attorney_reviewed_at"
    t.datetime "exported_at"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_attorney_id"], name: "index_cases_on_assigned_attorney_id"
    t.index ["beneficiary_name_bidx"], name: "index_cases_on_beneficiary_name_bidx"
    t.index ["created_by_id"], name: "index_cases_on_created_by_id"
    t.index ["rfe_deadline"], name: "index_cases_on_rfe_deadline"
    t.index ["status"], name: "index_cases_on_status"
    t.index ["tenant_id", "case_number"], name: "index_cases_on_tenant_id_and_case_number", unique: true
    t.index ["tenant_id"], name: "index_cases_on_tenant_id"
    t.index ["uscis_receipt_number"], name: "index_cases_on_uscis_receipt_number"
  end

  create_table "draft_responses", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "case_id", null: false
    t.uuid "rfe_section_id", null: false
    t.integer "position", default: 0, null: false
    t.string "title"
    t.text "ai_generated_content"
    t.text "edited_content"
    t.text "final_content"
    t.integer "status", default: 0, null: false
    t.integer "version", default: 1
    t.jsonb "exhibit_references", default: []
    t.text "attorney_feedback"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_draft_responses_on_case_id"
    t.index ["rfe_section_id", "position"], name: "index_draft_responses_on_rfe_section_id_and_position"
    t.index ["rfe_section_id"], name: "index_draft_responses_on_rfe_section_id"
    t.index ["status"], name: "index_draft_responses_on_status"
    t.index ["tenant_id"], name: "index_draft_responses_on_tenant_id"
  end

  create_table "embeddings", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.string "embeddable_type", null: false
    t.uuid "embeddable_id", null: false
    t.text "content"
    t.integer "chunk_index", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "embedding", limit: 1536
    t.index ["embeddable_type", "embeddable_id"], name: "index_embeddings_on_embeddable_type_and_embeddable_id"
    t.index ["tenant_id"], name: "index_embeddings_on_tenant_id"
  end

  create_table "evidence_checklists", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "case_id", null: false
    t.uuid "rfe_section_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "priority", default: 0, null: false
    t.string "document_name", null: false
    t.text "description"
    t.text "guidance"
    t.boolean "is_collected", default: false
    t.uuid "linked_document_id"
    t.text "attorney_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_evidence_checklists_on_case_id"
    t.index ["linked_document_id"], name: "index_evidence_checklists_on_linked_document_id"
    t.index ["priority"], name: "index_evidence_checklists_on_priority"
    t.index ["rfe_section_id", "position"], name: "index_evidence_checklists_on_rfe_section_id_and_position"
    t.index ["rfe_section_id"], name: "index_evidence_checklists_on_rfe_section_id"
    t.index ["tenant_id"], name: "index_evidence_checklists_on_tenant_id"
  end

  create_table "exhibits", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "case_id", null: false
    t.uuid "rfe_document_id"
    t.string "label", null: false
    t.string "title"
    t.text "description"
    t.integer "position", default: 0, null: false
    t.string "page_range"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id", "label"], name: "index_exhibits_on_case_id_and_label", unique: true
    t.index ["case_id", "position"], name: "index_exhibits_on_case_id_and_position"
    t.index ["case_id"], name: "index_exhibits_on_case_id"
    t.index ["rfe_document_id"], name: "index_exhibits_on_rfe_document_id"
    t.index ["tenant_id"], name: "index_exhibits_on_tenant_id"
  end

  create_table "knowledge_docs", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "uploaded_by_id", null: false
    t.integer "doc_type", default: 0, null: false
    t.string "title", null: false
    t.text "content"
    t.string "visa_type"
    t.string "rfe_category"
    t.jsonb "metadata", default: {}
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "doc_type"], name: "index_knowledge_docs_on_tenant_id_and_doc_type"
    t.index ["tenant_id"], name: "index_knowledge_docs_on_tenant_id"
    t.index ["uploaded_by_id"], name: "index_knowledge_docs_on_uploaded_by_id"
    t.index ["visa_type", "rfe_category"], name: "index_knowledge_docs_on_visa_type_and_rfe_category"
  end

  create_table "rfe_documents", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "case_id", null: false
    t.uuid "uploaded_by_id", null: false
    t.integer "document_type", default: 0, null: false
    t.string "filename", null: false
    t.string "content_type"
    t.bigint "file_size"
    t.string "s3_key"
    t.text "extracted_text"
    t.text "ocr_text"
    t.integer "processing_status", default: 0, null: false
    t.jsonb "processing_metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id", "document_type"], name: "index_rfe_documents_on_case_id_and_document_type"
    t.index ["case_id"], name: "index_rfe_documents_on_case_id"
    t.index ["processing_status"], name: "index_rfe_documents_on_processing_status"
    t.index ["tenant_id"], name: "index_rfe_documents_on_tenant_id"
    t.index ["uploaded_by_id"], name: "index_rfe_documents_on_uploaded_by_id"
  end

  create_table "rfe_sections", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "case_id", null: false
    t.uuid "rfe_document_id"
    t.integer "position", default: 0, null: false
    t.integer "section_type", default: 0, null: false
    t.string "title"
    t.text "original_text"
    t.text "summary"
    t.string "cfr_reference"
    t.float "confidence_score"
    t.jsonb "ai_analysis", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id", "position"], name: "index_rfe_sections_on_case_id_and_position"
    t.index ["case_id"], name: "index_rfe_sections_on_case_id"
    t.index ["rfe_document_id"], name: "index_rfe_sections_on_rfe_document_id"
    t.index ["section_type"], name: "index_rfe_sections_on_section_type"
    t.index ["tenant_id"], name: "index_rfe_sections_on_tenant_id"
  end

  create_table "tenants", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "plan", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.jsonb "settings", default: {}
    t.integer "data_retention_days", default: 30
    t.string "encryption_key_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
  end

  create_table "users", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "jti", null: false
    t.uuid "tenant_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "role", default: 0, null: false
    t.string "bar_number"
    t.integer "status", default: 0, null: false
    t.jsonb "preferences", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tenant_id", "role"], name: "index_users_on_tenant_id_and_role"
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "tenants"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "cases", "tenants"
  add_foreign_key "cases", "users", column: "assigned_attorney_id"
  add_foreign_key "cases", "users", column: "created_by_id"
  add_foreign_key "draft_responses", "cases"
  add_foreign_key "draft_responses", "rfe_sections"
  add_foreign_key "draft_responses", "tenants"
  add_foreign_key "embeddings", "tenants"
  add_foreign_key "evidence_checklists", "cases"
  add_foreign_key "evidence_checklists", "rfe_documents", column: "linked_document_id"
  add_foreign_key "evidence_checklists", "rfe_sections"
  add_foreign_key "evidence_checklists", "tenants"
  add_foreign_key "exhibits", "cases"
  add_foreign_key "exhibits", "rfe_documents"
  add_foreign_key "exhibits", "tenants"
  add_foreign_key "knowledge_docs", "tenants"
  add_foreign_key "knowledge_docs", "users", column: "uploaded_by_id"
  add_foreign_key "rfe_documents", "cases"
  add_foreign_key "rfe_documents", "tenants"
  add_foreign_key "rfe_documents", "users", column: "uploaded_by_id"
  add_foreign_key "rfe_sections", "cases"
  add_foreign_key "rfe_sections", "rfe_documents"
  add_foreign_key "rfe_sections", "tenants"
  add_foreign_key "users", "tenants"
end
