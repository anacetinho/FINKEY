# FinKey AI Assistant - Technical Architecture & Data Flow Documentation

**Generated:** 2025-10-19
**Version:** FinKey 1.4.0

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Components](#architecture-components)
3. [System Prompt](#system-prompt)
4. [Available Tools/Functions](#available-toolsfunctions)
5. [Data Transmission & Privacy](#data-transmission--privacy)
6. [Complete Request Flow](#complete-request-flow)
7. [Code Implementation Details](#code-implementation-details)
8. [Configuration & Providers](#configuration--providers)

---

## Overview

The FinKey AI Assistant is a financial chatbot that helps users understand their personal finance data through natural language conversations. It uses OpenAI's GPT models (or compatible local LLMs) with **function calling** to retrieve and analyze financial data from the user's FinKey database.

### Key Features

- **Multi-Provider Support**: OpenAI or local LLMs (Ollama, LM Studio, etc.)
- **Function Calling**: AI can request specific financial data via structured tools
- **Streaming Responses**: Real-time text streaming for responsive UX
- **Scoped Data Access**: Only accesses data for the authenticated user's family
- **Privacy-Focused**: All data stays in user's database; only queried data is sent to LLM

---

## Architecture Components

### Core Models & Controllers

| Component | File Location | Purpose |
|-----------|--------------|---------|
| **ChatsController** | `app/controllers/chats_controller.rb` | Manages chat sessions (CRUD operations) |
| **Chat** | `app/models/chat.rb` | Chat model with messages relationship |
| **Message Hierarchy** | `app/models/message.rb`, `user_message.rb`, `assistant_message.rb` | Polymorphic message types |
| **Assistant** | `app/models/assistant.rb` | Main orchestrator for AI responses |
| **Assistant::Responder** | `app/models/assistant/responder.rb` | Handles streaming and function call flow |
| **Provider::Openai** | `app/models/provider/openai.rb` | OpenAI API integration |
| **AssistantResponseJob** | `app/jobs/assistant_response_job.rb` | Background job for async response generation |

### Assistant Modules

| Module | File Location | Purpose |
|--------|--------------|---------|
| **Assistant::Configurable** | `app/models/assistant/configurable.rb` | Defines system prompt and default functions |
| **Assistant::Provided** | `app/models/assistant/provided.rb` | LLM provider selection logic |
| **Assistant::Broadcastable** | `app/models/assistant/broadcastable.rb` | WebSocket broadcasting for live updates |
| **Assistant::FunctionToolCaller** | `app/models/assistant/function_tool_caller.rb` | Executes function calls requested by AI |

### Function Implementations

Each function inherits from `Assistant::Function` base class:

| Function | File Location | Purpose |
|----------|--------------|---------|
| **GetAccounts** | `app/models/assistant/function/get_accounts.rb` | Retrieves account list with balances |
| **GetTransactions** | `app/models/assistant/function/get_transactions.rb` | Searches transactions with filters |
| **GetIncomeStatement** | `app/models/assistant/function/get_income_statement.rb` | Income/expense analysis by category |
| **GetBalanceSheet** | `app/models/assistant/function/get_balance_sheet.rb` | Net worth and historical wealth data |
| **GetForecast** | `app/models/assistant/function/get_forecast.rb` | Financial projections (up to 24 months) |

---

## System Prompt

The AI assistant receives the following system instructions with every request:

### Full System Prompt

**Location:** `app/models/assistant/configurable.rb` → `default_instructions` method

```markdown
## Your identity

You are a friendly financial assistant for an open source personal finance application called "FinKey", which is short for "FinKey Finance".

## Your purpose

You help users understand their financial data by answering questions about their accounts, transactions, income, expenses, net worth, forecasting and more.

## Your rules

Follow all rules below at all times.

### General rules

- Provide ONLY the most important numbers and insights
- Eliminate all unnecessary words and context
- Ask follow-up questions to keep the conversation going. Help educate the user about their own data and entice them to ask more questions.
- Do NOT add introductions or conclusions
- Do NOT apologize or explain limitations

### Formatting rules

- Format all responses in markdown
- Format all monetary values according to the user's preferred currency
- Format dates in the user's preferred format: [USER_DATE_FORMAT]

#### User's preferred currency

FinKey is a multi-currency app where each user has a "preferred currency" setting.

When no currency is specified, use the user's preferred currency for formatting and displaying monetary values.

- Symbol: [USER_CURRENCY_SYMBOL]
- ISO code: [USER_CURRENCY_ISO]
- Default precision: [USER_CURRENCY_PRECISION]
- Default format: [USER_CURRENCY_FORMAT]
  - Separator: [USER_CURRENCY_SEPARATOR]
  - Delimiter: [USER_CURRENCY_DELIMITER]

### Rules about financial advice

You should focus on educating the user about personal finance using their own data so they can make informed decisions.

- Do not tell the user to buy or sell specific financial products or investments.
- Do not make assumptions about the user's financial situation. Use the functions available to get the data you need.

### Function calling rules

- Use the functions available to you to get user financial data and enhance your responses
- For functions that require dates, use the current date as your reference point: [CURRENT_DATE]
- If you suspect that you do not have enough data to 100% accurately answer, be transparent about it and state exactly what
  the data you're presenting represents and what context it is in (i.e. date range, account, etc.)
```

**Dynamic Variables:**
- `[USER_DATE_FORMAT]` - From `chat.user.family.date_format`
- `[USER_CURRENCY_*]` - From `chat.user.family.currency` (Money::Currency object)
- `[CURRENT_DATE]` - `Date.current` at time of request

---

## Available Tools/Functions

The AI has access to **5 functions** that retrieve financial data. Here's the complete breakdown:

### 1. get_accounts

**Purpose:** Retrieves all accounts with current and historical balances

**Parameters:** None (no user input required)

**Data Returned:**
```json
{
  "as_of_date": "2025-10-19",
  "accounts": [
    {
      "name": "Chase Checking",
      "balance": 5000.50,
      "currency": "USD",
      "balance_formatted": "$5,000.50",
      "classification": "asset",
      "type": "Account::Depository",
      "start_date": "2020-01-15",
      "is_plaid_linked": true,
      "status": "active",
      "historical_balances": {
        "start_date": "2020-10-19",
        "end_date": "2025-10-19",
        "interval": "1 month",
        "values": ["$3,200.00", "$3,450.00", "..."]
      }
    }
  ]
}
```

**Historical Data Range:** Up to 5 years, monthly intervals

**Scoping:** Only accounts belonging to `user.family`

---

### 2. get_transactions

**Purpose:** Search and filter transactions with pagination

**Parameters:**
- `page` (required, integer): Page number
- `order` (required, enum): "asc" or "desc"
- `search` (optional, string): Search transaction names
- `start_date` (optional, string): YYYY-MM-DD format
- `end_date` (optional, string): YYYY-MM-DD format
- `accounts` (optional, array): Filter by account names
- `categories` (optional, array): Filter by category names
- `merchants` (optional, array): Filter by merchant names
- `tags` (optional, array): Filter by tag names
- `amount` (optional, string): Amount value
- `amount_operator` (optional, enum): "equal", "less", "greater"

**Pagination:** 50 transactions per page (hardcoded limit)

**Data Returned:**
```json
{
  "transactions": [
    {
      "date": "2025-10-15",
      "amount": 45.99,
      "currency": "USD",
      "formatted_amount": "$45.99",
      "classification": "expense",
      "account": "Chase Checking",
      "category": "Groceries",
      "merchant": "Whole Foods",
      "tags": ["Food", "Weekly"],
      "is_transfer": false
    }
  ],
  "total_results": 1234,
  "page": 1,
  "page_size": 50,
  "total_pages": 25,
  "total_income": "$10,500.00",
  "total_expenses": "$8,200.00"
}
```

**Scoping:** Only transactions for accounts in `user.family`

**Performance Note:** Forced pagination encourages AI to use filters effectively and reduces token usage

---

### 3. get_income_statement

**Purpose:** Income and expense analysis by category for a time period

**Parameters:**
- `start_date` (required, string): YYYY-MM-DD format
- `end_date` (required, string): YYYY-MM-DD format

**Data Returned:**
```json
{
  "currency": "USD",
  "period": {
    "start_date": "2025-01-01",
    "end_date": "2025-10-19"
  },
  "income": {
    "total": "$50,000.00",
    "by_category": [
      {
        "name": "Salary",
        "total": "$48,000.00",
        "percentage_of_total": "96.0%",
        "subcategory_totals": []
      }
    ]
  },
  "expense": {
    "total": "$35,000.00",
    "by_category": [
      {
        "name": "Housing",
        "total": "$12,000.00",
        "percentage_of_total": "34.3%",
        "subcategory_totals": [
          {
            "name": "Rent",
            "total": "$10,000.00",
            "percentage_of_total": "28.6%"
          }
        ]
      }
    ]
  },
  "insights": {
    "net_income": "$15,000.00",
    "savings_rate": "30.0%",
    "median_monthly_income": "$5,000.00",
    "median_monthly_expenses": "$3,500.00",
    "avg_monthly_expenses": "$3,600.00"
  }
}
```

**Hierarchical Categories:** Supports parent/child category structure

**Scoping:** Only transactions from `user.family`

---

### 4. get_balance_sheet

**Purpose:** Net worth analysis with historical trends

**Parameters:** None (uses last 5 years of data)

**Data Returned:**
```json
{
  "as_of_date": "2025-10-19",
  "oldest_account_start_date": "2020-01-15",
  "currency": "USD",
  "net_worth": {
    "current": "$75,000.00",
    "monthly_history": {
      "start_date": "2020-10-19",
      "end_date": "2025-10-19",
      "interval": "1 month",
      "values": ["$20,000.00", "$22,500.00", "..."]
    }
  },
  "assets": {
    "current": "$100,000.00",
    "monthly_history": { "..." }
  },
  "liabilities": {
    "current": "$25,000.00",
    "monthly_history": { "..." }
  },
  "insights": {
    "debt_to_asset_ratio": "25%"
  }
}
```

**Historical Data Range:** Up to 5 years, monthly intervals

**Classification:** Separate tracking for assets vs. liabilities

**Scoping:** Only visible accounts in `user.family`

---

### 5. get_forecast (FinKey Enhanced)

**Purpose:** Financial projections with customizable growth rates

**Parameters:**
- `timeline` (optional, enum): "1Y", "2Y", "5Y" (default: "1Y")
- `income_growth_rate` (optional, number): Annual % growth (e.g., 5.0 = 5%)
- `expense_growth_rate` (optional, number): Annual % growth (e.g., 3.0 = 3%)

**Data Returned:**
```json
{
  "as_of_date": "2025-10-19",
  "timeline": "2Y",
  "has_sufficient_data": true,
  "current_net_worth": "$75,000.00",
  "projected_net_worth": "$95,000.00",
  "projected_change": "$20,000.00",
  "monthly_income": "$5,000.00",
  "monthly_expenses": "$3,500.00",
  "monthly_cash_flow": "$1,500.00",
  "total_projected_cash_flow": "$36,000.00",
  "income_growth_rate": 3.0,
  "expense_growth_rate": 2.0,
  "forecast_series": {
    "start_date": "2025-10-19",
    "end_date": "2027-10-19",
    "interval": "1 month",
    "data_points": [
      {
        "date": "2025-11-19",
        "value": "$76,500.00"
      }
    ]
  },
  "future_events": [
    {
      "date": "2026-01-15",
      "amount": "$10,000.00",
      "type": "income",
      "description": "Annual bonus"
    }
  ]
}
```

**FinKey Enhancement:** Extended forecasting up to 24 months (vs. Maybe's original 12 months)

**Future Events:** User-defined income/expense events are factored into projections

**Scoping:** Based on `user.family` transaction history

---

## Data Transmission & Privacy

### What Data is Sent to OpenAI?

**IMPORTANT:** The AI does NOT have access to all user data by default. Data is only sent when:

1. **User asks a question** → AI analyzes question
2. **AI determines it needs data** → Requests specific function(s)
3. **Function executes locally** → Queries FinKey database
4. **Results returned to AI** → Only the function output is sent to OpenAI

### Example Flow: "How much did I spend on groceries last month?"

**Step 1: User Question Sent to OpenAI**
```json
{
  "model": "gpt-4.1",
  "input": [
    {
      "role": "user",
      "content": "How much did I spend on groceries last month?"
    }
  ],
  "instructions": "[SYSTEM_PROMPT]",
  "tools": [
    { "type": "function", "name": "get_transactions", "..." },
    { "type": "function", "name": "get_income_statement", "..." }
  ]
}
```

**Step 2: AI Requests Function Call**
```json
{
  "function_name": "get_transactions",
  "function_args": {
    "page": 1,
    "order": "desc",
    "start_date": "2025-09-01",
    "end_date": "2025-09-30",
    "categories": ["Groceries"]
  }
}
```

**Step 3: FinKey Executes Function Locally**

- Database query: `SELECT * FROM transactions WHERE family_id = ? AND category = 'Groceries' AND date BETWEEN ? AND ?`
- **NO data sent to OpenAI yet**

**Step 4: Function Result Sent to OpenAI**
```json
{
  "transactions": [
    { "date": "2025-09-28", "amount": 89.43, "merchant": "Whole Foods" },
    { "date": "2025-09-21", "amount": 67.21, "merchant": "Safeway" }
  ],
  "total_expenses": "$425.18"
}
```

**Step 5: AI Generates Final Response**
```
"You spent $425.18 on groceries last month across 12 transactions.
Your top grocery store was Whole Foods ($156.32)."
```

### Data Minimization Strategies

1. **Pagination Limits:** Transactions capped at 50 per request
2. **Time-Series Optimization:** Historical data sent as formatted strings, not raw values
3. **Selective Fields:** Only essential transaction fields included (no internal IDs, metadata)
4. **Date Range Enforcement:** Functions encourage specific date ranges vs. "all time"
5. **No Automatic Syncing:** AI never automatically fetches data; always user-initiated

### Privacy Guarantees

| Aspect | Implementation |
|--------|---------------|
| **User Isolation** | All functions scoped to `Current.user.family` |
| **Multi-Tenancy** | Family-level data separation in database |
| **API Key Security** | Stored encrypted in database (`Setting` model) |
| **Local Execution** | All database queries run on user's server |
| **No Data Retention** | OpenAI API configured with zero data retention (per OpenAI's enterprise settings) |

### What Data is NEVER Sent?

- User email addresses or authentication credentials
- Internal database IDs (account_id, transaction_id, etc.)
- Plaid connection tokens
- Complete transaction history (only filtered results)
- Account numbers or sensitive financial identifiers
- Other family members' data (if multi-user)

---

## Complete Request Flow

### Lifecycle of a Chat Message

```
User types message in UI
         ↓
ChatsController#create
         ↓
Chat.start!(prompt, model: "gpt-4.1")
  - Creates Chat record
  - Creates UserMessage record
         ↓
UserMessage.after_create_commit
  → Chat#ask_assistant_later(message)
         ↓
AssistantResponseJob.perform_later(message)
  (Background job via Sidekiq)
         ↓
AssistantResponseJob#perform(message)
  → message.request_response
         ↓
Chat#ask_assistant(message)
  → assistant.respond_to(message)
         ↓
Assistant#respond_to(message)
  1. Creates empty AssistantMessage
  2. Gets LLM provider (OpenAI or local LLM)
  3. Creates Assistant::Responder
  4. Sets up event listeners:
     - :output_text → Stream text to UI
     - :response → Handle function calls
         ↓
Assistant::Responder#respond
  → llm.chat_response(
       prompt,
       model: "gpt-4.1",
       instructions: SYSTEM_PROMPT,
       functions: [get_accounts, get_transactions, ...],
       streamer: proc { |chunk| ... }
     )
         ↓
Provider::Openai#chat_response
  → OpenAI::Client.responses.create(
       parameters: {
         model: "gpt-4.1",
         input: [ { role: "user", content: prompt } ],
         instructions: SYSTEM_PROMPT,
         tools: [ { type: "function", ... } ],
         stream: proc { |chunk| ... }
       }
     )
         ↓
OpenAI API returns stream chunks:
  - "output_text" chunks → Broadcast to UI via Turbo Stream
  - "response" chunk with function_requests
         ↓
Assistant::Responder detects function_requests
  → FunctionToolCaller#fulfill_requests
       ↓
       For each function_request:
         - Find function class (e.g., GetTransactions)
         - Instantiate with user: fn.new(user)
         - Execute: fn.call(parsed_args)
         - Return result as ToolCall::Function
         ↓
         Results sent back to OpenAI as function_call_output
         ↓
         OpenAI generates final response with data
         ↓
         Stream final text to UI
         ↓
AssistantMessage saved with complete response
         ↓
User sees final answer in chat UI
```

### Streaming Implementation

**Real-time Updates via Hotwire Turbo Streams:**

1. **Thinking Indicator:** Shows while waiting for first token
2. **Text Streaming:** Each chunk broadcasts via WebSocket to append text
3. **Function Execution:** "Analyzing your data..." message shown during function calls
4. **Final Response:** Thinking indicator removed, complete message displayed

**WebSocket Broadcasting:**
- Uses Rails' built-in Action Cable
- `chat_channel` subscription per chat
- Turbo Stream actions: `append`, `replace`, `remove`

---

## Code Implementation Details

### Key Classes & Methods

#### 1. Chat Model (app/models/chat.rb)

```ruby
class Chat < ApplicationRecord
  belongs_to :user
  has_many :messages

  # Start new chat with initial user message
  def self.start!(prompt, model:)
    create!(
      title: generate_title(prompt),
      messages: [ UserMessage.new(content: prompt, ai_model: model) ]
    )
  end

  # Queue background job for AI response
  def ask_assistant_later(message)
    clear_error
    AssistantResponseJob.perform_later(message)
  end

  # Synchronous AI response (called by background job)
  def ask_assistant(message)
    assistant.respond_to(message)
  end

  # Get configured assistant for this chat
  def assistant
    Assistant.for_chat(self)
  end
end
```

#### 2. Assistant (app/models/assistant.rb)

```ruby
class Assistant
  include Provided, Configurable, Broadcastable

  # Factory method to create assistant with config
  def self.for_chat(chat)
    config = config_for(chat)
    new(chat, instructions: config[:instructions], functions: config[:functions])
  end

  # Main response orchestration
  def respond_to(message)
    assistant_message = AssistantMessage.new(chat: chat, content: "", ai_model: message.ai_model)
    llm_provider = get_model_provider(message.ai_model)

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_tool_caller: function_tool_caller,
      llm: llm_provider
    )

    # Event listeners for streaming
    responder.on(:output_text) do |text|
      assistant_message.append_text!(text)
    end

    responder.on(:response) do |data|
      if data[:function_tool_calls].present?
        assistant_message.tool_calls = data[:function_tool_calls]
      else
        chat.update_latest_response!(data[:id])
      end
    end

    responder.respond(previous_response_id: chat.latest_assistant_response_id)
  rescue => e
    chat.add_error(e)
  end
end
```

#### 3. Provider::Openai (app/models/provider/openai.rb)

```ruby
class Provider::Openai < Provider
  include LlmConcept

  def initialize(access_token, base_url: nil, model: nil)
    client_options = { access_token: access_token }
    client_options[:uri_base] = base_url if base_url.present? # For local LLMs
    @client = ::OpenAI::Client.new(client_options)
    @custom_model = model
  end

  # Main chat method using OpenAI Responses API
  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    effective_model = @custom_model.present? ? @custom_model : model

    chat_config = ChatConfig.new(
      functions: functions,
      function_results: function_results
    )

    # Streaming proxy that normalizes chunks
    stream_proxy = if streamer.present?
      proc do |chunk|
        parsed_chunk = ChatStreamParser.new(chunk).parsed
        streamer.call(parsed_chunk) unless parsed_chunk.nil?
      end
    end

    raw_response = client.responses.create(parameters: {
      model: effective_model,
      input: chat_config.build_input(prompt),
      instructions: instructions,
      tools: chat_config.tools,
      previous_response_id: previous_response_id,
      stream: stream_proxy
    })

    # Return parsed response
  end
end
```

#### 4. Function Base Class (app/models/assistant/function.rb)

```ruby
class Assistant::Function
  def initialize(user)
    @user = user
  end

  # Override in subclasses
  def call(params = {})
    raise NotImplementedError
  end

  # Define function schema for OpenAI
  def to_definition
    {
      name: name,
      description: description,
      params_schema: params_schema,
      strict: strict_mode?
    }
  end

  private
    attr_reader :user

    def family
      user.family
    end

    # Helper to convert time series for AI (saves tokens)
    def to_ai_time_series(series)
      {
        start_date: series.start_date,
        end_date: series.end_date,
        interval: series.interval,
        values: series.values.map { |v| v.trend.current.format }
      }
    end
end
```

#### 5. Example Function: GetAccounts (app/models/assistant/function/get_accounts.rb)

```ruby
class Assistant::Function::GetAccounts < Assistant::Function
  def self.name
    "get_accounts"
  end

  def self.description
    "Use this to see what accounts the user has along with their current and historical balances"
  end

  def call(params = {})
    {
      as_of_date: Date.current,
      accounts: family.accounts.includes(:balances).map do |account|
        {
          name: account.name,
          balance: account.balance,
          currency: account.currency,
          balance_formatted: account.balance_money.format,
          classification: account.classification,
          type: account.accountable_type,
          start_date: account.start_date,
          is_plaid_linked: account.plaid_account_id.present?,
          status: account.status,
          historical_balances: historical_balances(account)
        }
      end
    }
  end

  private
    def historical_balances(account)
      start_date = [ account.start_date, 5.years.ago.to_date ].max
      period = Period.custom(start_date: start_date, end_date: Date.current)
      balance_series = account.balance_series(period: period, interval: "1 month")

      to_ai_time_series(balance_series)
    end
end
```

### OpenAI API Specifics

**Endpoint Used:** `/v1/responses` (OpenAI Responses API)

**Why Responses API?**
- Supports multi-turn conversations with `previous_response_id`
- Optimized for function calling with strict schemas
- Better streaming performance

**Request Format:**
```ruby
{
  model: "gpt-4.1",
  input: [
    { role: "user", content: "What's my net worth?" },
    # Function results appended if follow-up
    { type: "function_call_output", call_id: "abc123", output: "{...}" }
  ],
  instructions: "[SYSTEM_PROMPT]",
  tools: [
    {
      type: "function",
      name: "get_balance_sheet",
      description: "...",
      parameters: { type: "object", properties: {...} },
      strict: true
    }
  ],
  previous_response_id: "resp_xyz789", # For multi-turn
  stream: proc { |chunk| ... }
}
```

**Response Chunks (Streaming):**
```ruby
# Text chunk
{ type: "output_text", data: "Your current net worth is " }

# Function request chunk
{
  type: "response",
  data: {
    id: "resp_abc123",
    function_requests: [
      {
        call_id: "call_xyz",
        function_name: "get_balance_sheet",
        function_args: "{}"
      }
    ]
  }
}
```

---

## Configuration & Providers

### Provider Registry Architecture

**Location:** `app/models/provider/registry.rb` (not shown, but referenced)

**Concept-Based Providers:**
```ruby
# LLM providers implement LlmConcept
Provider::Registry.for_concept(:llm).providers
  # => [Provider::Openai, Provider::LocalLlm]

# Get provider for specific model
provider = Provider::Registry.for_concept(:llm).get_provider(:openai)
```

### UI-Based Configuration (FinKey Exclusive)

**Location:** `/settings/hosting` (Settings::HostingsController)

**Settings Model:** Uses `rails-settings-cached` gem

**Available Settings:**
```ruby
Setting.ai_assistant_enabled        # Boolean: Toggle assistant on/off
Setting.ai_provider                 # String: "openai" or "local_llm"
Setting.openai_access_token         # String: OpenAI API key
Setting.local_llm_base_url          # String: e.g., "http://localhost:11434"
Setting.local_llm_model             # String: e.g., "llama2", "mistral"
```

**Provider Initialization:**
```ruby
# From app/models/assistant/provided.rb
def get_model_provider(ai_model)
  registry.providers.find { |provider| provider.supports_model?(ai_model) }
end

# Registry loads providers based on settings:
if Setting.ai_provider == "openai"
  Provider::Openai.new(Setting.openai_access_token)
elsif Setting.ai_provider == "local_llm"
  Provider::Openai.new(
    "dummy-token", # Local LLMs often don't need real tokens
    base_url: Setting.local_llm_base_url,
    model: Setting.local_llm_model
  )
end
```

### Local LLM Support

**Compatible Providers:**
- Ollama (http://localhost:11434)
- LM Studio (http://localhost:1234)
- Any OpenAI-compatible API

**Configuration Example:**
```ruby
# Via UI at /settings/hosting
ai_provider: "local_llm"
local_llm_base_url: "http://192.168.1.100:11434"
local_llm_model: "llama2"
```

**Code Adaptation:**
```ruby
# Provider::Openai automatically uses custom base URL
@client = ::OpenAI::Client.new(
  access_token: "dummy",
  uri_base: "http://192.168.1.100:11434" # Overrides default OpenAI endpoint
)
```

### Environment Variables (Docker/Self-Hosted)

**Legacy Configuration (Still Supported):**
```bash
# .env file
OPENAI_ACCESS_TOKEN=sk-proj-...
```

**Docker Compose:**
```yaml
services:
  web:
    environment:
      OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN:-}
```

**Important:** UI settings take precedence over environment variables

---

## Summary

### Data Flow in One Sentence

> User asks question → Background job → OpenAI receives question + system prompt + function definitions → AI requests specific data → FinKey queries database locally → Results sent to OpenAI → AI generates answer → Response streamed to user

### Key Takeaways

1. **Privacy-First Design:** Only user-requested data is sent to LLM
2. **Function-Driven:** AI cannot access data without explicit function calls
3. **Scoped Access:** All queries filtered by `user.family`
4. **Streaming UX:** Real-time response updates via WebSockets
5. **Flexible Providers:** Support for OpenAI and local LLMs
6. **UI Configuration:** No need to edit environment files for AI setup
7. **Token Optimization:** Pagination, formatted time series, selective fields

### Architecture Highlights

- **Modular Functions:** Easy to add new financial analysis tools
- **Provider Pattern:** Swap LLM providers without changing core logic
- **Background Jobs:** Non-blocking response generation
- **Hotwire Integration:** Modern reactive UI without heavy JavaScript
- **Multi-Currency Aware:** Respects user's preferred currency throughout

---

## Files Referenced in This Documentation

### Controllers
- `app/controllers/chats_controller.rb`
- `app/controllers/settings/hostings_controller.rb`

### Models
- `app/models/chat.rb`
- `app/models/message.rb`
- `app/models/user_message.rb`
- `app/models/assistant_message.rb`
- `app/models/assistant.rb`
- `app/models/assistant/configurable.rb`
- `app/models/assistant/provided.rb`
- `app/models/assistant/broadcastable.rb`
- `app/models/assistant/responder.rb`
- `app/models/assistant/function.rb`
- `app/models/assistant/function_tool_caller.rb`
- `app/models/assistant/function/get_accounts.rb`
- `app/models/assistant/function/get_transactions.rb`
- `app/models/assistant/function/get_income_statement.rb`
- `app/models/assistant/function/get_balance_sheet.rb`
- `app/models/assistant/function/get_forecast.rb`
- `app/models/provider/openai.rb`
- `app/models/provider/openai/chat_config.rb`
- `app/models/provider/openai/chat_parser.rb`
- `app/models/provider/openai/chat_stream_parser.rb`
- `app/models/setting.rb`

### Jobs
- `app/jobs/assistant_response_job.rb`

### Database Tables (Inferred)
- `chats` - Chat sessions
- `messages` - Polymorphic messages (UserMessage, AssistantMessage, DeveloperMessage)
- `settings` - Application-wide settings (from rails-settings-cached)
- `users` - User accounts
- `families` - Multi-user groups (data scoping)
- `accounts` - Financial accounts
- `transactions` - Transaction records
- `balances` - Historical balance snapshots

---

**End of Documentation**

For questions or updates, refer to the codebase at the file locations listed above.
