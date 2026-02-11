source "https://rubygems.org"

# ruby "~> 3.3"

# Core Rails & Server
gem "rails", "~> 8.0.4"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "redis", "~> 5.0"
gem "bootsnap", require: false

# Background Jobs
gem "sidekiq", "~> 7.2"
gem "sidekiq-scheduler", "~> 5.0"

# Authentication & Authorization
gem "devise", "~> 4.9"
gem "devise-jwt", "~> 0.12"
gem "pundit", "~> 2.3"

# Multi-tenancy
gem "acts_as_tenant", "~> 1.0"

# API
gem "rack-cors"
gem "blueprinter", "~> 1.0"
gem "pagy", "~> 6.0"

# State Machine
gem "aasm", "~> 5.5"

# Audit Trail - using custom AuditLog model (paper_trail incompatible with Rails 8)
# gem "paper_trail", "~> 15.0"

# Friendly URLs
gem "friendly_id", "~> 5.5"

# Encryption
gem "lockbox", "~> 1.3"
gem "blind_index", "~> 2.4"

# Vector Search (pgvector)
gem "neighbor", "~> 0.4"

# Rate Limiting
gem "rack-attack", "~> 6.7"

# File Processing
gem "aws-sdk-s3", "~> 1.0"
gem "pdf-reader", "~> 2.12"

# AI / LLM
gem "ruby-openai", "~> 7.0"

# Monitoring
gem "lograge", "~> 0.14"

# Environment
gem "dotenv-rails", groups: [:development, :test]

# Windows timezone data
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.0"
  gem "pry-rails"
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "pundit-matchers", "~> 3.1"
  gem "webmock", "~> 3.0"
  gem "simplecov", require: false
  gem "database_cleaner-active_record"
end
