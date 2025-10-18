# Expense Reimbursement Feature

## Overview

The expense reimbursement feature allows users to track expenses that are later reimbursed, such as business expenses paid personally that will be reimbursed by an employer. This feature ensures that:

- Reimbursements increase account balances (like income)
- Transactions remain classified as expenses for budget calculations
- Net worth calculations correctly reflect the positive impact of reimbursements
- Forecasting accurately calculates expense medians considering reimbursements

## Business Logic

### Core Concept
Expense reimbursements use a special category flag `allows_negative_expenses` to indicate that positive amounts in this category should be treated as reimbursements (reducing total expenses) rather than additional expenses.

### Example Scenario
- User pays €600 in business expenses from personal account
- User receives €250 reimbursement for part of those expenses
- **Expected behavior**:
  - Net worth: Should increase by €250 (from €2400 to €2650)
  - Budget expenses: Should show net €350 (€600 - €250)
  - Forecasting: Should use €350 as the monthly expense median

## Architecture

### Domain Model
```
Category
├── allows_negative_expenses: boolean (flag for reimbursement categories)

Transaction
├── belongs_to :category
├── amount: decimal (positive for reimbursements in reimbursement categories)

Entry (double-entry accounting)
├── amount: decimal (stores transaction amount)
├── classification: string (income/expense)
├── entryable: polymorphic (Transaction, Trade, etc.)
```

### Key Components

#### 1. Entry Model (`app/models/entry.rb`)
- **Responsibility**: Handle amount storage and classification logic
- **Key methods**:
  - `adjust_amount_for_expense_reimbursements`: Callback to store positive amounts for reimbursements
  - `classification`: Always returns "expense" for reimbursement categories

#### 2. Balance Calculation (`app/models/balance/`)
- **BaseCalculator**: Handles expense reimbursements as inflows to account balances
- **ForwardCalculator**: Bypasses sign flip for reimbursement entries

#### 3. Income Statement (`app/models/income_statement/`)
- **Totals**: Uses AmountCalculator for consistent expense amount logic
- **FamilyStats/CategoryStats**: Calculates medians with combined monthly totals

#### 4. AmountCalculator Concern (`app/models/concerns/amount_calculator.rb`)
- **Responsibility**: Shared SQL logic for expense amount calculations
- **Methods**:
  - `expense_amount_sql`: Handles reimbursement negation logic
  - `income_amount_sql`: Standard absolute value logic

## Implementation Approach

### Phase 1: Entry Model Logic
```ruby
# Store positive amounts for reimbursements
def adjust_amount_for_expense_reimbursements
  if transaction? && transaction.category&.allows_negative_expenses? && amount < 0
    self.amount = amount.abs
  end
end

# Always classify reimbursements as expenses
def classification
  if transaction? && transaction.category&.allows_negative_expenses?
    "expense"
  else
    amount.to_f < 0 ? "income" : "expense"
  end
end
```

### Phase 2: Balance Calculation Fixes
```ruby
# BaseCalculator - treat reimbursements as inflows
expense_reimbursements = entries.select { |e| 
  e.transaction? && e.amount > 0 && e.transaction.category&.allows_negative_expenses?
}
expense_reimbursement_inflow_sum = -expense_reimbursements.sum(&:amount)

# ForwardCalculator - bypass sign flip
def signed_entry_flows(entries)
  expense_reimbursements = entries.select { |e| 
    e.transaction? && e.amount > 0 && e.transaction.category&.allows_negative_expenses?
  }
  expense_reimbursement_flows = expense_reimbursements.sum(&:amount)
  signed_regular_flows + expense_reimbursement_flows
end
```

### Phase 3: Income Statement SQL Updates
```sql
-- Combined monthly totals for median calculation
WITH period_totals AS (
  SELECT
    date_trunc(:interval, ae.date) as period,
    CASE 
      WHEN c.allows_negative_expenses = true THEN 'expense'
      WHEN ae.amount < 0 THEN 'income' 
      ELSE 'expense' 
    END as classification,
    SUM(
      CASE 
        WHEN c.allows_negative_expenses = true 
          THEN ae.amount * COALESCE(er.rate, 1) * -1
        ELSE ae.amount * COALESCE(er.rate, 1)
      END
    ) as total
  FROM transactions t
  -- ... joins and conditions
  GROUP BY period, CASE 
      WHEN c.allows_negative_expenses = true THEN 'expense'
      WHEN ae.amount < 0 THEN 'income' 
      ELSE 'expense' 
    END
)
```

## Issues Found and Solutions

### Issue 1: Docker File Synchronization
**Problem**: Changes to local files weren't being reflected in Docker container
**Solution**: Manually copy files using `docker cp` command after modifications
```bash
docker cp /path/to/file.rb container:/rails/path/to/file.rb
```

### Issue 2: Balance Calculation Logic
**Problem**: Initial flows calculation fixes weren't working because `signed_entry_flows` method was still using standard logic
**Solution**: Override `signed_entry_flows` method in ForwardCalculator to handle expense reimbursements separately

### Issue 3: PostgreSQL GROUP BY Errors
**Problem**: Using `c.allows_negative_expenses` in CASE statements without including it in GROUP BY clause
**Solution**: Add `c.allows_negative_expenses` to GROUP BY clause in SQL queries

### Issue 4: Median Calculation Separation
**Problem**: Expense reimbursements were being treated as separate entries instead of combined monthly totals
- Month with €600 expenses + €250 reimbursement was creating two rows: [€600, €250]
- Median calculation returned €175 instead of expected €350

**Solution**: Remove `c.allows_negative_expenses` from GROUP BY clause and use single SUM with CASE logic to combine all expenses for the same period

## Data Flow

### Transaction Entry
1. User creates expense transaction with reimbursement category
2. Entry model stores positive amount and classifies as "expense"
3. Balance calculator treats as inflow to account

### Balance Calculation
1. ForwardCalculator processes entries for account
2. Expense reimbursements bypass normal sign flip
3. Account balance increases by reimbursement amount

### Income Statement
1. Totals query combines expenses and reimbursements by period
2. Stats queries calculate medians using combined monthly totals
3. Forecasting uses correct median values

### Budget Display
1. Budget calculations use expense classification
2. Reimbursements reduce total expense amounts
3. Net expense amounts displayed in budget views

## Testing Scenarios

### Scenario 1: Basic Reimbursement
- Create €600 expense transaction
- Create €250 reimbursement transaction (same category with `allows_negative_expenses = true`)
- **Verify**: Net worth increases by €250, budget shows €350 net expense

### Scenario 2: Median Calculation
- Multiple months with varying expenses and reimbursements
- **Verify**: Forecasting uses combined monthly totals for median calculation

### Scenario 3: Currency Conversion
- Reimbursements in different currencies
- **Verify**: Exchange rates properly applied in calculations

## Files Modified

### Core Models
- `app/models/entry.rb` - Entry classification and amount storage
- `app/models/concerns/amount_calculator.rb` - Shared SQL logic

### Balance Calculation
- `app/models/balance/base_calculator.rb` - Flow calculation logic
- `app/models/balance/forward_calculator.rb` - Sign handling for reimbursements

### Income Statement
- `app/models/income_statement/totals.rb` - Expense totals calculation
- `app/models/income_statement/family_stats.rb` - Family-level median/average stats
- `app/models/income_statement/category_stats.rb` - Category-level median/average stats

## Future Considerations

### Performance
- Consider adding database indexes for `categories.allows_negative_expenses`
- Monitor query performance with large datasets

### User Experience
- Add clear indicators in UI for reimbursement categories
- Consider adding reimbursement-specific transaction types

### Reporting
- Add specific reports for reimbursement tracking
- Consider integration with expense reporting tools

## Conclusion

The expense reimbursement feature successfully handles the complex accounting requirements of tracking reimbursable expenses while maintaining accurate financial reporting across net worth, budgets, and forecasting. The implementation follows Rails conventions and maintains the existing double-entry accounting principles.