# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About FinKey

FinKey is a fork of Maybe Finance with enhanced features:
- **Flexible AI Assistant**: UI-based configuration for OpenAI or local LLMs (Ollama, LM Studio, etc.)
- **Yahoo Finance Integration**: Real-time exchange rates and market data via `Provider::YahooFinance`
- **Advanced Expense Reimbursement**: Complex transaction handling
- **Extended Forecasting**: 24-month financial projections
- **Enhanced Docker Setup**: Improved deployment experience

The app runs in two modes via `Rails.application.config.app_mode`:
- `"managed"`: Hosted by the Maybe team
- `"self_hosted"`: User-hosted via Docker (FinKey's primary mode)

## Tech Stack

- **Web Framework**: Ruby on Rails 7.2.x with Ruby 3.4.4
- **Database**: PostgreSQL >9.3
- **Jobs**: Sidekiq + Redis with sidekiq-cron for scheduled tasks
- **Frontend**:
  - Hotwire (Turbo + Stimulus) for reactive UI
  - TailwindCSS v4.x with custom design system
  - ViewComponent for reusable components
  - D3.js for financial visualizations
  - Lucide Icons (via custom `icon` helper)
- **Asset Pipeline**: Propshaft + Importmap (no webpack/vite)
- **Testing**: Minitest + fixtures (no RSpec/FactoryBot)
- **Code Quality**: Rubocop (rails-omakase), Biome (JS/TS), ERB Lint, Brakeman (security)
- **External Integrations**:
  - Plaid (bank syncing)
  - Stripe (payments, managed mode only)
  - OpenAI (AI assistant via `ruby-openai` gem)
  - Yahoo Finance (market data, FinKey exclusive)
  - Synth API (Maybe's market data)

## Common Development Commands

### Development Server
- `bin/dev` - Start development server (Rails, Sidekiq, Tailwind CSS watcher)
- `bin/rails server` - Start Rails server only
- `bin/rails console` - Open Rails console

### Testing
- `bin/rails test` - Run all tests
- `bin/rails test:db` - Run tests with database reset
- `bin/rails test:system` - Run system tests only (use sparingly - they take longer)
- `bin/rails test test/models/account_test.rb` - Run specific test file
- `bin/rails test test/models/account_test.rb:42` - Run specific test at line

### Linting & Formatting
- `bin/rubocop` - Run Ruby linter (uses rubocop-rails-omakase)
- `npm run lint` - Check JavaScript/TypeScript code (Biome)
- `npm run lint:fix` - Fix JavaScript/TypeScript issues (Biome)
- `npm run format` - Format JavaScript/TypeScript code (Biome)
- `npm run style:check` - Check all JS/TS style issues (Biome)
- `npm run style:fix` - Fix all JS/TS style issues (Biome)
- `bin/brakeman` - Run security analysis
- `bundle exec erb_lint ./app/**/*.erb -a` - Lint ERB templates with auto-fix

### Database
- `bin/rails db:prepare` - Create and migrate database
- `bin/rails db:migrate` - Run pending migrations
- `bin/rails db:rollback` - Rollback last migration
- `bin/rails db:seed` - Load seed data

### Setup
- `bin/setup` - Initial project setup (installs dependencies, prepares database)
- `setup.bat` (Windows) / `setup.sh` (Linux/macOS) - One-click Docker setup for self-hosting

### Demo Data
- `rake demo_data:default` - Load demo data for development (credentials: `user@finkey.local` / `password`)

## Pre-Pull Request CI Workflow

ALWAYS run these commands before opening a pull request:

1. **Tests** (Required):
   - `bin/rails test` - Run all tests (always required)
   - `bin/rails test:system` - Run system tests (only when applicable, they take longer)

2. **Linting** (Required):
   - `bin/rubocop -f github -a` - Ruby linting with auto-correct
   - `bundle exec erb_lint ./app/**/*.erb -a` - ERB linting with auto-correct

3. **Security** (Required):
   - `bin/brakeman --no-pager` - Security analysis

Only proceed with pull request creation if ALL checks pass.

## General Development Rules

### Authentication Context
- Use `Current.user` for the current user. Do NOT use `current_user`.
- Use `Current.family` for the current family. Do NOT use `current_family`.

### Development Guidelines
- Prior to generating any code, carefully read the project conventions and guidelines
- Ignore i18n methods and files. Hardcode strings in English for now to optimize speed of development
- Do not run `rails server` in your responses
- Do not run `touch tmp/restart.txt`
- Do not run `rails credentials`
- Do not automatically run migrations

## AI Assistant (FinKey Enhanced)

### Overview
FinKey's AI assistant provides financial insights via OpenAI or local LLMs:
- Financial analysis and insights
- Transaction categorization assistance
- Merchant detection automation
- Interactive financial Q&A

### Configuration (UI-Based)
**IMPORTANT**: Unlike Maybe Finance, FinKey allows AI configuration through the UI at `/settings/hosting`:
- **Provider Selection**: Choose OpenAI or Local LLM
- **OpenAI**: Set `openai_access_token` via UI (stored in `Setting` model)
- **Local LLM**: Configure `local_llm_base_url` and `local_llm_model` via UI
- No need to edit `.env` files or rebuild Docker containers

### Technical Details
- **Models**: `gpt-4.1` (chat), `gpt-4.1-mini` (categorization) for OpenAI
- **API Endpoint**: OpenAI's Responses API (`/v1/responses`)
- **Ruby Gem**: `ruby-openai` v8.1.0+
- **Provider Registry**: `Provider::Registry.for_concept(:llm)` manages providers
- **Settings Controller**: `Settings::HostingsController` handles UI-based configuration

### Common Issues & Troubleshooting

#### "Failed to generate response" Error
**Symptoms**: Chat interface shows "Failed to generate response. Please try again."

**Root Causes & Solutions**:

1. **Missing/Invalid API Key**:
   ```bash
   # Check if API key is set
   docker-compose exec web rails runner "puts ENV['OPENAI_ACCESS_TOKEN'].present?"
   
   # Test API key validity
   docker-compose exec web rails runner "puts Provider::Registry.for_concept(:llm).get_provider(:openai)"
   ```

2. **Docker Environment Variable Configuration**:
   ```yaml
   # INCORRECT in compose.yml:
   OPENAI_ACCESS_TOKEN: ${sk-proj-actual-api-key-here}
   
   # CORRECT in compose.yml:
   OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN:-sk-proj-actual-api-key-here}
   ```

3. **Provider Initialization Issues**:
   ```bash
   # Check Rails logs for provider creation
   docker-compose logs web | grep "Provider::Openai"
   docker-compose logs web | grep "Provider::Registry"
   ```

#### Docker Rebuild Required
After fixing environment variables, always rebuild containers:
```bash
docker-compose down
docker-compose build
docker-compose up -d
```

#### Debugging Steps
1. Check Docker logs: `docker-compose logs web | grep -i openai`
2. Test in Rails console: `Provider::Registry.for_concept(:llm).providers`
3. Verify API key: `ENV['OPENAI_ACCESS_TOKEN'].present?`
4. Test provider creation: `Provider::Openai.new(ENV['OPENAI_ACCESS_TOKEN'])`

### Implementation Notes
- OpenAI provider is loaded via `Provider::Registry.for_concept(:llm)`
- Chat responses use streaming for real-time updates
- Function calling enables data retrieval (accounts, transactions, etc.)
- Rate limiting and error handling built into provider layer

## Important File Locations

### Configuration & Setup
- `config/routes.rb` - Application routes
- `config/application.rb` - Rails application configuration (includes `app_mode` setting)
- `Procfile.dev` - Foreman process definitions (web, css, worker)
- `.env.example` / `.env.local.example` - Environment variable templates
- `app/assets/tailwind/maybe-design-system.css` - Design system tokens (read-only, never modify)

### Key Directories
- `app/models/` - Domain models and business logic (skinny controllers, fat models)
- `app/models/provider/` - External integration providers (OpenAI, Yahoo Finance, Plaid, etc.)
- `app/components/DS/` - Design system components (buttons, badges, dialogs)
- `app/components/UI/` - Feature-specific UI components
- `app/controllers/settings/` - Self-hosted configuration (`HostingsController`)
- `app/javascript/controllers/` - Global Stimulus controllers
- `app/helpers/application_helper.rb` - Includes `icon` helper (always use this, not `lucide_icon`)

### Services & Background Jobs
- `app/models/**/syncer.rb` - Data sync logic (e.g., `Account::Syncer`, `Holding::Syncer`)
- `app/jobs/` - Sidekiq background jobs (e.g., `SyncAccountsJob`, `CreateChatResponseJob`)
- `app/services/yahoo_finance_service.rb` - Yahoo Finance API wrapper (FinKey exclusive)

## High-Level Architecture

### Core Domain Model
The application is built around financial data management with these key relationships:
- **User** → has many **Accounts** → has many **Transactions**
- **Account** types: checking, savings, credit cards, investments, crypto, loans, properties
- **Transaction** → belongs to **Category**, can have **Tags** and **Rules**
- **Investment accounts** → have **Holdings** → track **Securities** via **Trades**

### API Architecture
The application provides both internal and external APIs:
- Internal API: Controllers serve JSON via Turbo for SPA-like interactions
- External API: `/api/v1/` namespace with Doorkeeper OAuth and API key authentication
- API responses use Jbuilder templates for JSON rendering
- Rate limiting via Rack Attack with configurable limits per API key

### Sync & Import System
Two primary data ingestion methods:
1. **Plaid Integration**: Real-time bank account syncing
   - `PlaidItem` manages connections
   - `Sync` tracks sync operations
   - Background jobs handle data updates
2. **CSV Import**: Manual data import with mapping
   - `Import` manages import sessions
   - Supports transaction and balance imports
   - Custom field mapping with transformation rules

### Background Processing
Sidekiq handles asynchronous tasks:
- Account syncing (`SyncAccountsJob`)
- Import processing (`ImportDataJob`)
- AI chat responses (`CreateChatResponseJob`)
- Scheduled maintenance via sidekiq-cron

### Frontend Architecture
- **Hotwire Stack**: Turbo + Stimulus for reactive UI without heavy JavaScript
- **ViewComponents**: Reusable UI components in `app/components/`
- **Stimulus Controllers**: Handle interactivity, organized alongside components
- **Charts**: D3.js for financial visualizations (time series, donut, sankey)
- **Styling**: Tailwind CSS v4.x with custom design system
  - Design system defined in `app/assets/tailwind/maybe-design-system.css`
  - Always use functional tokens (e.g., `text-primary` not `text-white`)
  - Prefer semantic HTML elements over JS components
  - Use `icon` helper for icons, never `lucide_icon` directly

### Multi-Currency Support (FinKey Enhanced)
- All monetary values stored in base currency (user's primary currency)
- **Exchange rates**: Fetched from Yahoo Finance (`Provider::YahooFinance`) or Synth API
- **Yahoo Finance Integration**: Toggle via UI at `/settings/hosting` (`Setting.use_yahoo_finance`)
- `Money` objects handle currency conversion and formatting
- Historical exchange rates for accurate reporting
- Exchange rate providers implement `ExchangeRateConcept` interface

### Provider Architecture (FinKey Core)
FinKey uses a provider pattern for external integrations:
- **Provider::Registry**: Central registry managing providers by concept (`:llm`, `:security`, `:exchange_rate`)
- **Base Provider**: `Provider` model with `with_provider_response` error handling
- **Concepts**: Ruby modules defining provider interfaces (e.g., `SecurityConcept`, `ExchangeRateConcept`)
- **Available Providers**:
  - `Provider::Openai`: AI chat and categorization (via `ruby-openai` gem)
  - `Provider::YahooFinance`: Exchange rates and security prices (FinKey exclusive)
  - `Provider::Synth`: Maybe's market data API (original)
  - `Provider::Plaid`: Bank account syncing (includes `Provider::PlaidSandbox` for testing)
  - `Provider::Stripe`: Payment processing (managed mode)
  - `Provider::Github`: GitHub integration for version updates and releases

### Security & Authentication
- Session-based auth for web users
- API authentication via:
  - OAuth2 (Doorkeeper) for third-party apps
  - API keys with JWT tokens for direct API access
- Scoped permissions system for API access
- Strong parameters and CSRF protection throughout

### Testing Philosophy
- Comprehensive test coverage using Rails' built-in Minitest
- Fixtures for test data (avoid FactoryBot)
- Keep fixtures minimal (2-3 per model for base cases)
- VCR for external API testing
- System tests for critical user flows (use sparingly)
- Test helpers in `test/support/` for common scenarios
- Only test critical code paths that significantly increase confidence
- Write tests as you go, when required

### Performance Considerations
- Database queries optimized with proper indexes
- N+1 queries prevented via includes/joins
- Background jobs for heavy operations
- Caching strategies for expensive calculations
- Turbo Frames for partial page updates

### Self-Hosted Configuration (FinKey)
Settings managed via UI (`/settings/hosting`) and stored in `Setting` model (using `rails-settings-cached` gem):
- **AI Assistant**: `ai_assistant_enabled`, `ai_provider`, `openai_access_token`, `local_llm_base_url`, `local_llm_model`
- **Data Sources**: `use_yahoo_finance`, `synth_api_key`
- **User Management**: `require_invite_for_signup`, `require_email_confirmation`
- All settings accessible via `Setting.setting_name` (e.g., `Setting.use_yahoo_finance`)
- Changes take effect immediately without container rebuilds

### Development Workflow
- Feature branches merged to `main`
- Docker support for consistent environments
- Environment variables via `.env` files
- Lookbook for component development (`/lookbook`)
- Letter Opener for email preview in development

## Project Conventions

### Convention 1: Minimize Dependencies
- Push Rails to its limits before adding new dependencies
- Strong technical/business reason required for new dependencies
- Favor old and reliable over new and flashy

### Convention 2: Skinny Controllers, Fat Models
- Business logic in `app/models/` folder, avoid `app/services/`
- Use Rails concerns and POROs for organization
- Models should answer questions about themselves: `account.balance_series` not `AccountSeries.new(account).call`

### Convention 3: Hotwire-First Frontend
- **Native HTML preferred over JS components**
  - Use `<dialog>` for modals, `<details><summary>` for disclosures
- **Leverage Turbo frames** for page sections over client-side solutions
- **Query params for state** over localStorage/sessions
- **Server-side formatting** for currencies, numbers, dates
- **Always use `icon` helper** in `application_helper.rb`, NEVER `lucide_icon` directly

### Convention 4: Optimize for Simplicity
- Prioritize good OOP domain design over performance
- Focus performance only on critical/global areas (avoid N+1 queries, mindful of global layouts)

### Convention 5: Database vs ActiveRecord Validations
- Simple validations (null checks, unique indexes) in DB
- ActiveRecord validations for convenience in forms (prefer client-side when possible)
- Complex validations and business logic in ActiveRecord

## TailwindCSS Design System

### Design System Rules
- **Always reference `app/assets/tailwind/maybe-design-system.css`** for primitives and tokens
- **Use functional tokens** defined in design system:
  - `text-primary` instead of `text-white`
  - `bg-container` instead of `bg-white`
  - `border border-primary` instead of `border border-gray-200`
- **NEVER create new styles** in design system files without permission
- **Always generate semantic HTML**

## Component Architecture

### Component Organization
Components are organized in `app/components/` with two main directories:
- **DS/** (Design System): Core UI components (buttons, badges, icons, dialogs)
- **UI/** (User Interface): Feature-specific components (account cards, transaction lists)

Each component consists of:
- `component_name_component.rb` - Ruby class defining component logic
- `component_name_component.html.erb` - ERB template
- `component_name_controller.js` - Stimulus controller (if needed, located alongside component)

### ViewComponent vs Partials Decision Making

**Use ViewComponents when:**
- Element has complex logic or styling patterns
- Element will be reused across multiple views/contexts
- Element needs structured styling with variants/sizes
- Element requires interactive behavior or Stimulus controllers
- Element has configurable slots or complex APIs
- Element needs accessibility features or ARIA support

**Use Partials when:**
- Element is primarily static HTML with minimal logic
- Element is used in only one or few specific contexts
- Element is simple template content
- Element doesn't need variants, sizes, or complex configuration
- Element is more about content organization than reusable functionality

**Component Guidelines:**
- Prefer components over partials when available
- Keep domain logic OUT of view templates
- Logic belongs in component files, not template files

### Stimulus Controller Guidelines

**Declarative Actions (Required):**
```erb
<!-- GOOD: Declarative - HTML declares what happens -->
<div data-controller="toggle">
  <button data-action="click->toggle#toggle" data-toggle-target="button">Show</button>
  <div data-toggle-target="content" class="hidden">Hello World!</div>
</div>
```

**Controller Best Practices:**
- Keep controllers lightweight and simple (< 7 targets)
- Use private methods and expose clear public API
- Single responsibility or highly related responsibilities
- Component controllers stay in component directory, global controllers in `app/javascript/controllers/`
- Pass data via `data-*-value` attributes, not inline JavaScript

## Testing Philosophy

### General Testing Rules
- **ALWAYS use Minitest + fixtures** (NEVER RSpec or factories)
- Keep fixtures minimal (2-3 per model for base cases)
- Create edge cases on-the-fly within test context
- Use Rails helpers for large fixture creation needs

### Test Quality Guidelines
- **Write minimal, effective tests** - system tests sparingly
- **Only test critical and important code paths**
- **Test boundaries correctly:**
  - Commands: test they were called with correct params
  - Queries: test output
  - Don't test implementation details of other classes

### Testing Examples

```ruby
# GOOD - Testing critical domain business logic
test "syncs balances" do
  Holding::Syncer.any_instance.expects(:sync_holdings).returns([]).once
  assert_difference "@account.balances.count", 2 do
    Balance::Syncer.new(@account, strategy: :forward).sync_balances
  end
end

# BAD - Testing ActiveRecord functionality
test "saves balance" do 
  balance_record = Balance.new(balance: 100, currency: "USD")
  assert balance_record.save
end
```

### Stubs and Mocks
- Use `mocha` gem
- Prefer `OpenStruct` for mock instances
- Only mock what's necessary

## FinKey-Specific Features

### Yahoo Finance Integration
- **Location**: `app/models/provider/yahoo_finance.rb`, `app/services/yahoo_finance_service.rb`
- **Purpose**: Free alternative to Synth API for market data and exchange rates
- **Toggle**: UI setting at `/settings/hosting` (`Setting.use_yahoo_finance`)
- **Implements**: `SecurityConcept` (security prices) and `ExchangeRateConcept` (exchange rates)
- **Python Backend**: Uses Python `yfinance` library via subprocess calls
- **Exchange Mapping**: MIC codes to Yahoo suffixes (e.g., `XLON` → `.L` for London)

### UI-Based LLM Configuration
- **Location**: `app/controllers/settings/hostings_controller.rb`, `app/models/setting.rb`
- **Purpose**: Configure AI providers without editing `.env` or rebuilding Docker
- **Settings**:
  - `ai_assistant_enabled` - Toggle AI assistant on/off
  - `ai_provider` - Choose "openai" or "local_llm"
  - `openai_access_token` - OpenAI API key
  - `local_llm_base_url` - Ollama/LM Studio endpoint (e.g., `http://localhost:11434`)
  - `local_llm_model` - Model name (e.g., `llama2`, `mistral`)
- **Storage**: `rails-settings-cached` gem stores in database, cached in memory

### Enhanced Forecasting
- **Location**: `app/models/forecast.rb`
- **Purpose**: 24-month financial projections with trend analysis
- **Features**: Extended from Maybe's forecasting with longer projection periods

### One-Click Docker Setup
- **Scripts**: `setup.bat` (Windows), `setup.sh` (Linux/macOS)
- **Purpose**: Automated Docker deployment with environment setup
- **Process**: Checks Docker, creates `.env`, builds containers, starts services, opens browser