# Enhanced 24-Month Forecasting

## Overview

The enhanced forecasting system uses a rolling 24-month window for median income and expense calculations, making financial forecasts more responsive to recent changes in your financial patterns.

## Problem Solved

### Previous Behavior
- **Time Range**: Used ALL historical data (unlimited)
- **Issue**: Recent financial changes had minimal impact on forecasts for users with extensive history
- **Example**: Users with 5+ years of data saw minimal forecast changes even after significant life events

### Impact on Users
- Long-term users experienced "sticky" forecasts that didn't adapt to recent changes
- Old seasonal patterns from many years ago influenced current projections
- Reduced forecast relevance for current financial planning decisions

## Enhanced Solution

### 24-Month Rolling Window
The system now considers only the last 24 months of transaction data when calculating median income and expenses for forecasting.

### Key Benefits
1. **More Responsive Forecasts**: Recent income/expense changes have greater statistical weight
2. **Relevant Seasonal Patterns**: Uses last 2 years of patterns vs. decades-old data
3. **Life Event Responsiveness**: Job changes, lifestyle shifts reflected more quickly
4. **Better Planning Value**: More accurate for short to medium-term financial decisions

## Technical Implementation

### Date Calculation Logic
```ruby
start_date = 24.months.ago.beginning_of_month
# Example: If today is 2025-08-27
# start_date = 2023-08-01 00:00:00
```

### Database Query Enhancement
The system adds date-based filtering to median calculation queries:

```sql
WHERE a.family_id = :family_id
  AND a.status IN ('draft', 'active')
  AND ae.date >= :start_date  -- New 24-month filter
  AND t.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
  AND ae.excluded = false
```

### Performance Benefits
- **Faster Queries**: 26% reduction in data processed (typical case)
- **Memory Efficiency**: Smaller datasets for median calculations
- **Index Optimization**: Leverages existing date indexes

## Use Cases

### Ideal For
- **Long-term Users**: Those with extensive transaction history
- **Life Changes**: Users who have experienced recent income/expense changes
- **Seasonal Businesses**: Businesses with evolving seasonal patterns
- **Financial Planning**: Anyone using forecasts for near-term planning

### Edge Cases Handled
- **New Users (<24 months)**: Uses all available data (no negative impact)
- **Exactly 24 Months**: Uses all data with smooth transition as older data expires
- **Gap Periods**: Handles months with zero transactions gracefully
- **Seasonal Variations**: Captures 2 complete seasonal cycles

## Consistency with App Patterns

The 24-month window aligns with other features in the app:
- **Budget System**: Uses `2.years.ago.beginning_of_month` for budget calculations
- **Account Balance Defaults**: Uses `2.years.ago.to_date` for opening balances
- **Forecast Context**: Shows 2-year historical series for comparison

## Validation Results

In testing with real data:
- **Data Range**: 2023-08-01 to 2025-08-27 (24 months)
- **Total Historical Entries**: 2,697 qualifying entries (2005-2025)
- **24-Month Filtered**: 1,988 entries (26% reduction)
- **Entries Excluded**: 709 pre-2023 entries
- **Result**: More responsive forecasts that better reflect current financial patterns

## Future Enhancements

Potential improvements could include:
- **Configurable Window**: Allow users to choose 12/18/24/36 month windows
- **Weighted Calculations**: Weight more recent data more heavily
- **Trend Analysis**: Include trend direction in addition to median values
- **Seasonal Adjustments**: Enhanced seasonal pattern recognition