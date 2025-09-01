# Expense Reimbursement Tracking

## Overview

The expense reimbursement feature allows users to track expenses that are later reimbursed, such as business expenses paid personally that will be reimbursed by an employer. This ensures accurate financial reporting across net worth, budgets, and forecasting.

## Business Logic

### Core Concept
Expense reimbursements use a special category flag `allows_negative_expenses` to indicate that positive amounts in this category should be treated as reimbursements (reducing total expenses) rather than additional expenses.

### Example Scenario
- User pays €600 in business expenses from personal account
- User receives €250 reimbursement for part of those expenses
- **Result**:
  - Net worth increases by €250 (account balance goes up)
  - Budget shows net €350 expense (€600 - €250)
  - Forecasting uses €350 as the monthly expense median

## How to Use

### Setting Up Reimbursement Categories
1. Go to **Categories** in your dashboard
2. Create a new expense category (e.g., "Business Expenses - Reimbursable")
3. Enable the "Allow negative expenses" option for reimbursement handling

### Recording Expenses and Reimbursements
1. **Record the Expense**: Create a transaction for the amount you paid (e.g., €600)
2. **Record the Reimbursement**: Create a positive transaction in the same category (e.g., €250)
3. The system automatically handles the accounting to show net expenses

### Budget and Forecasting Impact
- **Budget View**: Shows combined net expense amount (€600 - €250 = €350)
- **Net Worth**: Increases by reimbursement amount (€250)
- **Forecasting**: Uses net monthly totals for accurate future projections

## Technical Architecture

### Domain Model
```
Category
├── allows_negative_expenses: boolean (reimbursement flag)

Transaction  
├── belongs_to :category
├── amount: decimal (positive for reimbursements in reimbursement categories)

Entry (double-entry accounting)
├── amount: decimal (stores transaction amount)
├── classification: string (always "expense" for reimbursement categories)
├── entryable: polymorphic (Transaction, Trade, etc.)
```

### Key Components

#### Entry Classification
- Transactions in reimbursement categories are always classified as "expense"
- Positive amounts are stored and treated as expense reductions
- Maintains proper double-entry accounting principles

#### Balance Calculation
- Reimbursements are treated as inflows to account balances
- Account balances increase by reimbursement amounts
- Net worth calculations properly reflect reimbursement benefits

#### Income Statement Integration
- Monthly expense totals combine regular expenses with reimbursements
- Median calculations use combined monthly totals (not separate entries)
- Forecasting uses accurate net expense amounts

## Data Flow

### 1. Transaction Entry
- User creates expense transaction with reimbursement category
- System stores positive amount and classifies as "expense"
- Balance calculator treats reimbursement as inflow to account

### 2. Balance Calculation
- Account balance increases by reimbursement amount
- Net worth properly reflects positive impact

### 3. Budget and Forecasting
- Budget calculations show net expense amounts
- Forecasting uses combined monthly totals for median calculation
- Reports display accurate expense reductions

## Example Usage Scenarios

### Business Expense Reimbursement
1. Pay €200 for business lunch (expense transaction)
2. Receive €200 reimbursement (positive transaction in same category)
3. Result: €0 net impact on budget, account balance increased by €200

### Partial Reimbursement
1. Pay €500 for conference attendance (expense transaction)
2. Receive €300 reimbursement (partial coverage)
3. Result: €200 net expense in budget, account balance increased by €300

### Multiple Reimbursements
1. Pay various business expenses throughout month totaling €800
2. Receive multiple reimbursements totaling €600
3. Result: €200 net monthly expense for forecasting purposes

## Benefits

### Accurate Financial Reporting
- **True Net Worth**: Reflects positive impact of reimbursements
- **Realistic Budgeting**: Shows actual out-of-pocket expenses
- **Better Forecasting**: Uses net amounts for future projections

### Accounting Compliance
- **Double-Entry Principles**: Maintains proper accounting structure
- **Audit Trail**: Clear transaction history for all reimbursements
- **Category Flexibility**: Can create multiple reimbursement categories

### User Experience
- **Simple Setup**: Just enable flag on expense categories
- **Intuitive Entry**: Record reimbursements as positive amounts
- **Clear Reporting**: See net impacts in budgets and forecasts

## Future Enhancements

Potential improvements could include:
- **Reimbursement Matching**: Link specific expenses to reimbursements
- **Approval Workflows**: Track reimbursement request status
- **Integration**: Connect with expense reporting tools
- **Reporting**: Dedicated reimbursement tracking reports