puts "Seeding database..."

# ============================================================
# Platform Tenant (for super admin)
# ============================================================
puts "\n--- Platform Tenant (super admin) ---"

platform_tenant = Tenant.find_or_create_by!(slug: "platform-admin") do |t|
  t.name = "Platform Administration"
  t.plan = :enterprise
  t.status = :active
  t.data_retention_days = 365
end
puts "  Platform tenant: #{platform_tenant.name}"

super_admin = User.find_or_initialize_by(email: "superadmin@rfeready.com")
if super_admin.new_record?
  super_admin.assign_attributes(
    first_name: "Super",
    last_name: "Admin",
    password: "SuperAdmin123!",
    password_confirmation: "SuperAdmin123!",
    role: :admin,
    status: :active,
    tenant: platform_tenant,
    is_super_admin: true,
    jti: SecureRandom.uuid,
    confirmed_at: Time.current
  )
  super_admin.save!
  puts "  Created super admin: #{super_admin.email}"
else
  puts "  Super admin already exists: #{super_admin.email}"
end

ActsAsTenant.current_tenant = nil

# Helper to create a user
def seed_user(tenant:, email:, first_name:, last_name:, role:, bar_number: nil)
  user = User.find_or_initialize_by(email: email)
  if user.new_record?
    user.assign_attributes(
      first_name: first_name,
      last_name: last_name,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: role,
      bar_number: bar_number,
      status: :active,
      tenant: tenant,
      jti: SecureRandom.uuid,
      confirmed_at: Time.current
    )
    user.save!
    puts "  Created #{role}: #{user.email}"
  else
    puts "  #{role.to_s.capitalize} already exists: #{user.email}"
  end
  user
end

# Helper to create a case
def seed_case(tenant:, attorney:, case_number:, visa_type:, petitioner:, beneficiary:, deadline_days:, received_days_ago: 7)
  rfe_case = RfeCase.find_or_initialize_by(case_number: case_number)
  if rfe_case.new_record?
    rfe_case.assign_attributes(
      tenant: tenant,
      created_by: attorney,
      assigned_attorney: attorney,
      visa_type: visa_type,
      petitioner_name: petitioner,
      beneficiary_name: beneficiary,
      rfe_received_date: received_days_ago.days.ago.to_date,
      rfe_deadline: deadline_days.days.from_now.to_date,
      notes: "Seeded case for testing."
    )
    rfe_case.save!
    puts "  Created case: #{rfe_case.case_number} (#{visa_type})"
  else
    puts "  Case already exists: #{rfe_case.case_number}"
  end
  rfe_case
end

# ============================================================
# Tenant 1: Demo Immigration Law Firm (existing)
# ============================================================
puts "\n--- Tenant 1: Demo Immigration Law Firm ---"

tenant1 = Tenant.find_or_create_by!(slug: "demo-firm") do |t|
  t.name = "Demo Immigration Law Firm"
  t.plan = :professional
  t.status = :active
  t.data_retention_days = 90
end
puts "  Tenant: #{tenant1.name}"

ActsAsTenant.current_tenant = tenant1

seed_user(tenant: tenant1, email: "admin@rfeready.com", first_name: "Admin", last_name: "User", role: :admin)
attorney1 = seed_user(tenant: tenant1, email: "attorney@rfeready.com", first_name: "Jane", last_name: "Attorney", role: :attorney, bar_number: "CA-123456")
seed_user(tenant: tenant1, email: "paralegal@rfeready.com", first_name: "John", last_name: "Paralegal", role: :paralegal)

seed_case(tenant: tenant1, attorney: attorney1, case_number: "RFE-DEMO-001", visa_type: "H-1B",
          petitioner: "Acme Technology Inc.", beneficiary: "Sample Beneficiary", deadline_days: 80)

# ============================================================
# Tenant 2: Pacific Visa Partners
# ============================================================
puts "\n--- Tenant 2: Pacific Visa Partners ---"

tenant2 = Tenant.find_or_create_by!(slug: "pacific-visa") do |t|
  t.name = "Pacific Visa Partners"
  t.plan = :enterprise
  t.status = :active
  t.data_retention_days = 180
end
puts "  Tenant: #{tenant2.name}"

ActsAsTenant.current_tenant = tenant2

seed_user(tenant: tenant2, email: "admin@pacificvisa.com", first_name: "Robert", last_name: "Chen", role: :admin)
attorney2 = seed_user(tenant: tenant2, email: "sarah@pacificvisa.com", first_name: "Sarah", last_name: "Williams", role: :attorney, bar_number: "NY-789012")
seed_user(tenant: tenant2, email: "mike@pacificvisa.com", first_name: "Mike", last_name: "Johnson", role: :paralegal)

seed_case(tenant: tenant2, attorney: attorney2, case_number: "PVP-2024-001", visa_type: "H-1B",
          petitioner: "TechGlobal Solutions", beneficiary: "Raj Patel", deadline_days: 45, received_days_ago: 14)
seed_case(tenant: tenant2, attorney: attorney2, case_number: "PVP-2024-002", visa_type: "L-1",
          petitioner: "InnoSoft International", beneficiary: "Wei Chen", deadline_days: 60, received_days_ago: 10)
seed_case(tenant: tenant2, attorney: attorney2, case_number: "PVP-2024-003", visa_type: "O-1",
          petitioner: "Creative Arts Studio", beneficiary: "Maria Gonzalez", deadline_days: 30, received_days_ago: 21)

# ============================================================
# Tenant 3: Liberty Immigration Group
# ============================================================
puts "\n--- Tenant 3: Liberty Immigration Group ---"

tenant3 = Tenant.find_or_create_by!(slug: "liberty-immigration") do |t|
  t.name = "Liberty Immigration Group"
  t.plan = :basic
  t.status = :active
  t.data_retention_days = 60
end
puts "  Tenant: #{tenant3.name}"

ActsAsTenant.current_tenant = tenant3

seed_user(tenant: tenant3, email: "admin@libertyimmigration.com", first_name: "Emily", last_name: "Davis", role: :admin)
attorney3 = seed_user(tenant: tenant3, email: "david@libertyimmigration.com", first_name: "David", last_name: "Martinez", role: :attorney, bar_number: "TX-345678")
seed_user(tenant: tenant3, email: "lisa@libertyimmigration.com", first_name: "Lisa", last_name: "Park", role: :viewer)

seed_case(tenant: tenant3, attorney: attorney3, case_number: "LIG-2024-001", visa_type: "EB-2",
          petitioner: "National Research Labs", beneficiary: "Amir Hassan", deadline_days: 90, received_days_ago: 5)
seed_case(tenant: tenant3, attorney: attorney3, case_number: "LIG-2024-002", visa_type: "H-1B",
          petitioner: "FinanceCore Inc.", beneficiary: "Yuki Tanaka", deadline_days: 20, received_days_ago: 30)

# ============================================================
# Feature Flags (for all tenants)
# ============================================================
puts "\n--- Feature Flags ---"
[ tenant1, tenant2, tenant3 ].each do |tenant|
  ActsAsTenant.current_tenant = tenant
  FeatureFlag.seed_defaults(tenant)
  puts "  Seeded feature flags for #{tenant.name}"
end

# ============================================================
puts "\n✅ Seeding complete!"
puts "\nLogin credentials:"
puts "  Super Admin:              superadmin@rfeready.com (Password: SuperAdmin123!)"
puts "  Tenant 1 - Demo Firm:       admin@rfeready.com | attorney@rfeready.com | paralegal@rfeready.com (Password: Password123!)"
puts "  Tenant 2 - Pacific Visa:    admin@pacificvisa.com | sarah@pacificvisa.com | mike@pacificvisa.com (Password: Password123!)"
puts "  Tenant 3 - Liberty Immigration: admin@libertyimmigration.com | david@libertyimmigration.com | lisa@libertyimmigration.com (Password: Password123!)"
