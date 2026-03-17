# RFE Ready API

Rails API backend for RFE Ready - an AI-powered platform for managing immigration Request for Evidence (RFE) cases.

## Overview

RFE Ready streamlines the RFE response process by providing:
- AI-powered RFE document analysis and classification
- Evidence checklist generation
- Draft response generation using GPT-4
- Semantic search across knowledge base
- Real-time collaboration features
- Multi-tenant architecture with role-based access control

## Technology Stack

- **Ruby**: 3.3.x
- **Rails**: 8.0
- **Database**: PostgreSQL 14+ with pgvector extension
- **Cache/Queue**: Redis 7
- **Background Jobs**: Sidekiq
- **Authentication**: Devise + JWT
- **Authorization**: Pundit
- **AI/ML**: OpenAI GPT-4, pgvector for embeddings
- **Real-time**: ActionCable (WebSockets)
- **File Storage**: AWS S3 (production), Local (development)
- **Email**: Resend (production)

## System Dependencies

### Required
- Ruby 3.3.x
- PostgreSQL 14+ with pgvector extension
- Redis 7+
- Bundler

### Optional (for development)
- Docker & Docker Compose
- AWS S3 credentials (for Active Storage in production)

## Local Development Setup

### 1. Install Dependencies

```bash
# Install Ruby dependencies
bundle install

# Install PostgreSQL 14 with Homebrew (macOS)
brew install postgresql@14
brew services start postgresql@14

# Install Redis
brew install redis
brew services start redis
```

### 2. Database Setup

```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed initial data (optional)
bin/rails db:seed
```

### 3. Environment Variables

Create `.env` file in the project root:

```bash
# Database
DATABASE_URL=postgresql://localhost/rfe_ready_development

# Redis
REDIS_URL=redis://localhost:6379/1

# Encryption keys (generate with: bin/rails lockbox:generate_key)
LOCKBOX_MASTER_KEY=your_lockbox_key_here
BLIND_INDEX_MASTER_KEY=your_blind_index_key_here

# JWT secret (generate with: bin/rails secret)
DEVISE_JWT_SECRET_KEY=your_jwt_secret_here

# OpenAI
OPENAI_API_KEY=your_openai_api_key_here

# AWS S3 (optional for development)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=us-east-1
AWS_BUCKET=your-bucket-name

# Resend (optional for development)
RESEND_API_KEY=your_resend_key_here

# Application
APP_HOST=localhost:3000
FRONTEND_URL=http://localhost:5173
```

### 4. Start Development Server

```bash
# Start Rails server
bin/rails server

# In a separate terminal, start Sidekiq
bundle exec sidekiq
```

API will be available at `http://localhost:3000`

## Running Tests

```bash
# Run full test suite
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

**Test Coverage**: 90.7% (951 examples across 88 files)

## Code Quality

```bash
# Run Rubocop linter
bin/rubocop

# Auto-fix Rubocop violations
bin/rubocop -A

# Run Brakeman security scanner
bin/brakeman
```

## Session Management

### JWT Token Refresh
- JWT tokens expire after **15 minutes** for enhanced security
- Tokens automatically **refresh on every API request**
- Fresh token sent in `Authorization` response header
- Frontend captures and stores the refreshed token automatically
- Users stay logged in indefinitely while active

### Idle Timeout
- Users are logged out after **15 minutes of inactivity**
- Warning modal shown at 14 minutes (frontend)
- Activity events (clicks, typing) reset the idle timer
- Works in conjunction with JWT expiry for consistent session behavior

### Implementation
```ruby
# JWT configuration in config/initializers/devise.rb
config.jwt do |jwt|
  jwt.expiration_time = 15.minutes.to_i
  jwt.dispatch_requests = [
    [ "POST", %r{^/api/v1/users/sign_in$} ],
    [ "*", %r{^/api/v1/} ] # Refresh on every request
  ]
end

# Token refresh handled by JwtRefresh concern
# app/controllers/concerns/jwt_refresh.rb
# Automatically included in Api::V1::BaseController
```

## Real-Time Features

The application uses ActionCable (WebSockets) for real-time features:

### Available Channels

1. **NotificationChannel** - Real-time user notifications
   - Broadcasts: User mentions, case assignments, system alerts
   - Stream: Per-user

2. **CaseUpdatesChannel** - Real-time case updates
   - Broadcasts: Comment added, status changed, document uploaded
   - Stream: Per-tenant (all users in organization see updates)

3. **DraftEditingChannel** - Collaborative draft editing
   - Features: Presence indicators, cursor positions, content synchronization
   - Auto-unlock on disconnect

### Testing Real-Time Features

**Live Comments:**
1. Open the same case in two browser windows (different users)
2. Post a comment in one window
3. Comment appears instantly in the other window

**Live Notifications:**
1. User A mentions User B in a comment
2. User B receives instant notification

**Collaborative Editing:**
1. Multiple users open the same draft response
2. See real-time presence and cursor positions

## Production Deployment

### Infrastructure
- **Hosting**: AWS EC2
- **Reverse Proxy**: nginx (via Docker)
- **SSL/TLS**: Cloudflare (Flexible mode)
- **Containers**: Docker Compose

### Deployment Process (CI/CD)

Automatic deployment via GitHub Actions on push to `main`:

1. **CI Pipeline** (`.github/workflows/ci.yml`):
   - Security scan (Brakeman)
   - Linting (Rubocop)
   - Tests (RSpec)

2. **Deployment** (after CI passes):
   - SSH to EC2 server
   - Pull latest code
   - Build Rails container
   - Run database migrations
   - Restart Rails + Sidekiq containers
   - Health check verification

### Manual Deployment

```bash
# SSH to production server
ssh -i /path/to/rfe-ready-key.pem ubuntu@your-ec2-host

# Navigate to project
cd /home/ubuntu/rfe-pilot

# Pull latest changes
cd rfe-ready-api && git pull origin main && cd ..

# Rebuild and restart
docker compose --env-file .env.production -f docker-compose.production.yml build rails
docker compose --env-file .env.production -f docker-compose.production.yml run --rm rails bin/rails db:migrate
docker compose --env-file .env.production -f docker-compose.production.yml up -d rails sidekiq

# Verify
curl -f http://localhost/up
```

## Architecture

### Multi-Tenancy
- Implemented via `acts_as_tenant` gem
- Row-level data isolation per organization
- Tenant context set via JWT token

### Authorization
- Pundit policies for all controllers
- Roles: `super_admin`, `admin`, `attorney`, `paralegal`, `viewer`
- Super admin: Cross-tenant access
- Regular users: Single-tenant access

### Background Jobs
- Powered by Sidekiq + Redis
- Job types:
  - Document processing (PDF parsing, classification)
  - AI generation (embeddings, draft responses)
  - Email notifications
  - Report generation

### AI/ML Pipeline
1. **Document Upload** → PDF parsing
2. **Text Extraction** → OpenAI embeddings (1536 dimensions)
3. **Storage** → pgvector for semantic search
4. **Classification** → GPT-4 section identification
5. **Response Generation** → GPT-4 draft creation

## API Documentation

API documentation available at `/api-docs` when running the server.

**Base URL (Production)**: `https://rfeready.com/api/v1`

### Authentication
```bash
# Login
POST /api/v1/users/sign_in
{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}

# Returns JWT token in Authorization header
# Include in subsequent requests:
# Authorization: Bearer <token>
```

### Key Endpoints
- `GET /api/v1/cases` - List cases
- `POST /api/v1/cases` - Create case
- `GET /api/v1/cases/:id` - Case details
- `POST /api/v1/cases/:id/start_analysis` - Start AI analysis
- `GET /api/v1/dashboard` - Dashboard metrics
- `GET /api/v1/knowledge/search?q=query` - Semantic search

## Security

### Implemented Measures
- JWT-based authentication with token rotation
- Bcrypt password hashing
- Pundit authorization on all endpoints
- Brakeman security scanning in CI
- Lockbox encryption for sensitive data
- Blind indexes for encrypted searchable fields
- CORS configured for frontend origin
- Request origin validation for WebSockets
- SQL injection protection (Rails parameterized queries)
- XSS protection (Rails escaping)

### Security Scanning
```bash
# Run Brakeman
bin/brakeman --no-pager

# Check for outdated gems with vulnerabilities
bundle audit check --update
```

## Database Schema

Key models:
- `Tenant` - Organizations
- `User` - Users with roles and authentication
- `RfeCase` - RFE cases
- `RfeDocument` - Uploaded RFE PDFs
- `RfeSection` - Classified sections from RFE
- `DraftResponse` - AI-generated responses
- `EvidenceChecklist` - Required evidence items
- `KnowledgeDoc` - Knowledge base documents
- `Embedding` - Vector embeddings for semantic search
- `Comment` - Case comments with mentions
- `SlackIntegration` - Slack webhook notifications
- `Webhook` - Custom webhook integrations

## Troubleshooting

### PostgreSQL Connection Issues
```bash
# Check if PostgreSQL is running
brew services list

# Restart PostgreSQL
brew services restart postgresql@14
```

### Redis Connection Issues
```bash
# Check if Redis is running
brew services list

# Restart Redis
brew services restart redis

# Test connection
redis-cli ping  # Should return PONG
```

### WebSocket Connection Failures
- Ensure ActionCable allowed origins are configured in `config/environments/production.rb`
- For Cloudflare Flexible SSL, both `https://` and `http://` origins must be allowed
- Check browser console for WebSocket errors
- Verify nginx proxy configuration for `/cable` endpoint

### Migration Issues
```bash
# Check migration status
bin/rails db:migrate:status

# Rollback last migration
bin/rails db:rollback

# Reset database (WARNING: destroys all data)
bin/rails db:reset
```

## Contributing

1. Create feature branch from `main`
2. Make changes and add tests
3. Ensure tests pass: `bundle exec rspec`
4. Ensure linting passes: `bin/rubocop`
5. Ensure security scan passes: `bin/brakeman`
6. Create pull request to `main`
7. Wait for CI checks to pass
8. Request review and merge

### Branch Protection
- Direct pushes to `main` are blocked
- Pull requests required
- CI checks must pass: `scan_ruby`, `lint`, `test`
- Branches must be up to date before merging

## License

Proprietary - All rights reserved

## Support

For issues or questions, contact the development team or create an issue in the GitHub repository.
