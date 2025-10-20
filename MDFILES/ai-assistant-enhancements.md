# AI Assistant Enhancements - Changelog

**Date:** 2025-10-19
**Version:** FinKey 1.4.0 Enhanced
**Target:** Local LLM users with 25k+ token context windows

---

## Overview

This document details enhancements made to the FinKey AI Assistant to better serve local LLM users with larger context windows. The changes prioritize **quality** and **comprehensive data access** over token conservation.

---

## Summary of Changes

### ✅ Phase 1: Critical Enhancements (COMPLETED)

1. **Holdings Data in get_accounts** - Investment accounts now include detailed holdings
2. **New Function: get_holdings** - Comprehensive portfolio analysis
3. **Configurable Pagination** - Larger limits for local LLMs (500 vs 50 transactions)
4. **New Function: get_trades** - Investment trading activity analysis
5. **Enhanced Transaction Details** - Added name, notes, and excluded status
6. **Enhanced Account Details** - Added subtype, institution, and other metadata
7. **Adaptive System Prompt** - Different instructions for local LLM vs OpenAI

---

## Detailed Changes

### 1. Enhanced get_accounts Function

**File:** `app/models/assistant/function/get_accounts.rb`

**New Data Added:**
- `subtype` - Account subtype (401k, IRA, Brokerage, etc.)
- `institution` - Bank/brokerage domain name
- `holdings` array (for Investment accounts only):
  - `security_name` - Full name of security
  - `ticker` - Stock ticker symbol
  - `qty` - Quantity owned
  - `price` - Current price per share
  - `amount` - Total position value
  - `formatted_amount` - Currency-formatted value
  - `weight` - Percentage of account balance
  - `avg_cost` - Average cost basis
  - `current_value` - Current market value

**Example Output:**
```json
{
  "name": "Vanguard Brokerage",
  "balance": 50000.0,
  "subtype": "brokerage",
  "institution": "vanguard.com",
  "holdings": [
    {
      "security_name": "Apple Inc.",
      "ticker": "AAPL",
      "qty": 50,
      "price": 170.0,
      "formatted_amount": "$8,500.00",
      "weight": 17.0,
      "avg_cost": "$150.00",
      "current_value": "$8,500.00"
    }
  ]
}
```

---

### 2. New Function: get_holdings

**File:** `app/models/assistant/function/get_holdings.rb`

**Purpose:** Detailed portfolio analysis across all investment accounts

**Parameters:**
- `account` (optional) - Filter by account name

**Data Returned:**
- Complete holdings list with performance metrics
- Unrealized gains/losses ($ and %)
- Cost basis vs. current value
- Portfolio-level allocation percentages
- Summary statistics:
  - Total unrealized gains/losses
  - Total cost basis
  - Average gain/loss percentage
  - Top performer
  - Worst performer

**Example Use Cases:**
- "How is my portfolio performing?"
- "What are my biggest holdings?"
- "Show me my gains and losses"
- "What's my Apple position worth?"

**Sample Output:**
```json
{
  "total_holdings": 10,
  "total_portfolio_value": 50000.0,
  "formatted_total_portfolio_value": "$50,000.00",
  "holdings": [
    {
      "account_name": "Vanguard Brokerage",
      "security_name": "Apple Inc.",
      "ticker": "AAPL",
      "qty": 50,
      "current_value": 8500.0,
      "cost_basis": 7500.0,
      "unrealized_gain_loss": 1000.0,
      "unrealized_gain_loss_percent": 13.33,
      "weight_in_portfolio": 17.0
    }
  ],
  "summary": {
    "total_unrealized_gain_loss": 5000.0,
    "total_cost_basis": 45000.0,
    "average_gain_loss_percent": 11.11,
    "top_performer": { "ticker": "NVDA", "security_name": "NVIDIA Corporation" },
    "worst_performer": { "ticker": "META", "security_name": "Meta Platforms Inc." }
  }
}
```

---

### 3. New Function: get_trades

**File:** `app/models/assistant/function/get_trades.rb`

**Purpose:** Investment trading activity (buy/sell transactions)

**Parameters:**
- `start_date` (optional) - YYYY-MM-DD
- `end_date` (optional) - YYYY-MM-DD
- `account` (optional) - Filter by account name
- `ticker` (optional) - Filter by security ticker
- `trade_type` (optional) - "buy" or "sell"

**Data Returned:**
- Trade details: date, type, security, quantity, price
- Total value per trade
- Summary statistics:
  - Total buys/sells
  - Total invested/divested
  - Net investment
  - Most traded security
  - Number of unique securities traded

**Example Use Cases:**
- "What did I buy last month?"
- "Show me my AAPL trades"
- "How much did I invest this year?"
- "What's my most traded stock?"

**Sample Output:**
```json
{
  "total_trades": 15,
  "trades": [
    {
      "date": "2025-10-15",
      "trade_type": "buy",
      "security_name": "Apple Inc.",
      "ticker": "AAPL",
      "quantity": 10,
      "price": 170.0,
      "formatted_price": "$170.00",
      "total_value": 1700.0,
      "formatted_total_value": "$1,700.00",
      "account": "Vanguard Brokerage"
    }
  ],
  "summary": {
    "total_buys": 10,
    "total_sells": 5,
    "total_invested": 15000.0,
    "total_divested": 8000.0,
    "net_investment": 7000.0,
    "most_traded_security": { "ticker": "AAPL", "security_name": "Apple Inc." },
    "securities_traded": 8
  }
}
```

---

### 4. Configurable Pagination

**Files Modified:**
- `app/models/assistant/function/get_transactions.rb`
- `app/models/assistant/function/get_trades.rb`
- `app/models/setting.rb`

**New Setting:**
- `Setting.ai_assistant_max_transactions` (default: 500 for local LLM)

**Logic:**
```ruby
def default_page_size
  if Setting.ai_provider == "local_llm"
    Setting.ai_assistant_max_transactions || 500
  else
    50 # Conservative limit for OpenAI
  end
end
```

**Impact:**
- Local LLM users get **10x more transactions** per request
- Reduces need for pagination
- Better quality analysis with complete data

---

### 5. Enhanced Transaction Details

**File:** `app/models/assistant/function/get_transactions.rb`

**New Fields Added:**
- `name` - Transaction description/memo
- `notes` - User notes on transaction
- `excluded` - Whether transaction is excluded from reports

**Before:**
```json
{
  "date": "2025-10-15",
  "amount": 45.99,
  "category": "Groceries",
  "merchant": "Whole Foods"
}
```

**After:**
```json
{
  "date": "2025-10-15",
  "name": "Weekly grocery shopping",
  "amount": 45.99,
  "category": "Groceries",
  "merchant": "Whole Foods",
  "notes": "Family dinner ingredients",
  "excluded": false
}
```

---

### 6. Adaptive System Prompt

**File:** `app/models/assistant/configurable.rb`

**Change:** System instructions now adapt based on `Setting.ai_provider`

**For Local LLM (new):**
```
- Provide comprehensive, detailed analysis with all relevant numbers and insights
- You have access to extensive financial data - use it to provide thorough, in-depth responses
- Include supporting details, context, and explanations
- When analyzing investments, include holdings details, performance metrics, and allocation analysis
- Ask thoughtful follow-up questions to deepen understanding
- Be conversational and helpful, but maintain professionalism
```

**For OpenAI (unchanged):**
```
- Provide ONLY the most important numbers and insights
- Eliminate all unnecessary words and context
- Do NOT add introductions or conclusions
- Do NOT apologize or explain limitations
```

**Updated Purpose Statement:**
> You help users understand their financial data by answering questions about their accounts, transactions, income, expenses, net worth, **investment holdings, trading activity,** forecasting and more.

---

### 7. Function Registration

**File:** `app/models/assistant/configurable.rb`

**Updated Function List:**
```ruby
def default_functions
  [
    Assistant::Function::GetTransactions,
    Assistant::Function::GetAccounts,
    Assistant::Function::GetHoldings,      # NEW
    Assistant::Function::GetTrades,        # NEW
    Assistant::Function::GetBalanceSheet,
    Assistant::Function::GetIncomeStatement,
    Assistant::Function::GetForecast
  ]
end
```

**Total Functions:** 7 (was 5)

---

## Configuration Changes

### New Settings

Add to `/settings/hosting` UI or `.env`:

```ruby
# AI Assistant - Transaction Limits
Setting.ai_assistant_max_transactions = 500  # Default for local LLM

# Or via environment variable:
AI_ASSISTANT_MAX_TRANSACTIONS=500
```

---

## Expected Quality Improvements

### Before Enhancements

**User:** "How is my investment portfolio doing?"

**AI Response:**
> I can see you have $50,000 in your Vanguard Brokerage account. The balance has increased 12% over the last year.

### After Enhancements

**User:** "How is my investment portfolio doing?"

**AI Response:**
> Your investment portfolio ($50,000 across 2 accounts) is performing well with an overall gain of $5,000 (11.11% unrealized return).

**Holdings Breakdown:**
- **AAPL** (50 shares): $8,500 (+13.3% gain, $1,000 unrealized)
- **MSFT** (30 shares): $12,000 (+10% gain, $1,091 unrealized)
- **NVDA** (20 shares): $15,000 (+18% gain, $2,290 unrealized) ⭐ Top Performer
- **VTSAX** (100 shares): $14,500 (+4.5% gain, $619 unrealized)

**Recent Activity (Last 30 Days):**
- 3 buy transactions totaling $4,200 invested
- Most active: AAPL (2 buys)

**Portfolio Allocation:**
- NVDA: 30% (largest position)
- MSFT: 24%
- VTSAX: 29%
- AAPL: 17%

Your tech holdings (AAPL, MSFT, NVDA) represent 71% of your portfolio and are outperforming your index fund (VTSAX) by an average of 8.6%. Consider rebalancing if you want to reduce sector concentration risk.

---

## Database Impact

### No Schema Changes Required ✅

All enhancements use **existing database tables and relationships**:
- `accounts` → `holdings` → `securities`
- `entries` → `trades`
- `transactions` → `category`, `merchant`, `tags`

### Query Performance Considerations

**Optimized with Includes:**
```ruby
# In get_accounts
family.accounts.includes(:balances, :current_holdings, :accountable)

# In get_holdings
account_scope.includes(current_holdings: :security)

# In get_trades
trades_query.includes(:security, entry: :account)
```

**Expected Performance:**
- Holdings query: ~50-100ms for 10-20 accounts
- Trades query: ~100-200ms for 100-200 trades
- No N+1 queries

---

## Testing Checklist

### Manual Testing

- [ ] Start chat with local LLM configured
- [ ] Ask: "What accounts do I have?" → Verify holdings appear for investment accounts
- [ ] Ask: "Show me all my holdings" → Verify get_holdings is called
- [ ] Ask: "What did I buy last month?" → Verify get_trades is called
- [ ] Ask: "Show me 100 transactions from this year" → Verify pagination allows 500+ results
- [ ] Ask: "How is AAPL performing?" → Verify detailed holdings analysis

### Automated Testing

Run existing test suite:
```bash
bin/rails test app/models/assistant/
```

---

## Rollback Instructions

If issues arise, revert these commits:

1. **Holdings in get_accounts:**
   ```bash
   git revert <commit-sha>
   ```

2. **Remove new functions from config:**
   ```ruby
   # In app/models/assistant/configurable.rb
   def default_functions
     [
       Assistant::Function::GetTransactions,
       Assistant::Function::GetAccounts,
       # Remove: GetHoldings, GetTrades
       Assistant::Function::GetBalanceSheet,
       Assistant::Function::GetIncomeStatement,
       Assistant::Function::GetForecast
     ]
   end
   ```

3. **Revert pagination changes:**
   ```ruby
   # In get_transactions.rb
   def default_page_size
     50  # Hardcoded back to original
   end
   ```

---

## Future Enhancement Ideas

### Phase 2 Candidates

1. **get_portfolio_summary** - Asset allocation, sector exposure, performance metrics
2. **get_budget** - Budget vs. actual analysis
3. **get_recurring_transactions** - Identify subscription patterns
4. **get_tax_summary** - Capital gains, deductions, tax-loss harvesting opportunities
5. **get_debt_summary** - Loan balances, interest paid, payoff projections

### Advanced Features

- Attach charts/graphs to responses (D3.js integration)
- Multi-account portfolio comparisons
- Scenario modeling ("What if I invest $1000/month?")
- ESG scoring for holdings
- Dividend tracking and projections

---

## Support & Troubleshooting

### Common Issues

**Issue:** "AI not showing holdings data"
- **Solution:** Verify `Setting.ai_provider == "local_llm"` and restart Rails server

**Issue:** "Still getting 50 transactions per page"
- **Solution:** Check `Setting.ai_assistant_max_transactions` is set to 500

**Issue:** "get_holdings function not found"
- **Solution:** Verify function is registered in `assistant/configurable.rb` default_functions

**Issue:** "Slow response times"
- **Solution:** Check database indexes on `holdings.account_id`, `holdings.security_id`, `trades.security_id`

---

## Contributors

- AI Assistant Enhancements implemented by Claude Code
- Based on user request for local LLM optimization (25k+ token context)

---

**End of Changelog**

For questions or additional enhancements, refer to the main documentation at `logs/ai-assistant-architecture.md`
