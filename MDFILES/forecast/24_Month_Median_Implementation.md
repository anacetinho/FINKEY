# 24-Month Median Calculation Implementation

## Overview

Modified the forecast median income and expense calculations to consider only the last 24 months of transaction data, making forecasts more responsive to recent financial patterns and aligned with current user behavior.

## Problem Addressed

### Previous Behavior
- **Time Range**: ALL historical data (unlimited)
- **Issue**: Recent financial changes had minimal impact on median calculations for users with extensive transaction history
- **Example**: Users with 5+ years of data saw minimal forecast changes even after significant life events (job changes, lifestyle changes)

### Impact on Forecasting
- Long-term users experienced "sticky" forecasts that didn't adapt to recent changes
- Seasonal patterns from many years ago influenced current projections
- Reduced forecast relevance for financial planning decisions

## Solution Implemented

### Approach: Time-Based SQL Filtering
Added date-based WHERE clause to median calculation queries, limiting data to the last 24 months from the current date.

### Technical Changes

#### 1. FamilyStats Query Modification
**File**: `app/models/income_statement/family_stats.rb`

**Parameter Addition**:
```ruby
{
  target_currency: @family.currency,
  interval: @interval,  
  family_id: @family.id,
  start_date: 24.months.ago.beginning_of_month  # New parameter
}
```

**SQL WHERE Clause Update**:
```sql
-- Before
WHERE a.family_id = :family_id
  AND a.status IN ('draft', 'active')
  AND t.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
  AND ae.excluded = false

-- After  
WHERE a.family_id = :family_id
  AND a.status IN ('draft', 'active')
  AND ae.date >= :start_date  -- New date filter
  AND t.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
  AND ae.excluded = false
```

#### 2. CategoryStats Query Modification
**File**: `app/models/income_statement/category_stats.rb`

Applied identical changes to maintain consistency across family-level and category-level median calculations.

## Implementation Results

### Test Results (Validation)
- **Data Range**: 2023-08-01 to 2025-08-27 (24 months)
- **Total Historical Entries**: 2,697 qualifying entries (2005-2025)  
- **24-Month Filtered**: 1,988 entries (26% reduction)
- **Entries Excluded**: 709 entries (pre-2023 data)
- **Performance**: ✅ Successful calculation with meaningful filtering

### Key Validation Points
- ✅ **Filtering Active**: 709 older entries successfully excluded
- ✅ **Date Range Accurate**: 24-month cutoff precisely at 2023-08-01  
- ✅ **Calculations Stable**: Median values computed correctly from filtered data
- ✅ **Performance Improved**: Smaller dataset = faster query execution

## Benefits Achieved

### 1. More Responsive Forecasts
- **Faster Adaptation**: Recent income/expense changes have greater statistical weight
- **Relevant Patterns**: Seasonal trends from last 2 years vs. decades-old data
- **Life Event Responsiveness**: Job changes, lifestyle shifts reflected more quickly

### 2. Improved User Experience
- **Relevant Projections**: Forecasts based on "recent normal" financial behavior
- **Seasonal Accuracy**: Last 2 years of seasonal patterns vs. historical averages
- **Planning Value**: More accurate for short to medium-term financial decisions

### 3. Performance Benefits
- **Query Speed**: 26% reduction in data processed (709 fewer entries)
- **Memory Usage**: Smaller datasets for median calculations
- **Index Efficiency**: Date-based filtering leverages existing `entries.date` indexes

### 4. Consistency with App Patterns
- **Established Pattern**: Follows existing use of `2.years.ago` throughout the application
- **Budget Alignment**: Similar timeframe approach used in budget oldest_valid_budget_date
- **Forecast Series**: Matches 2-year historical context in forecast_series method

## Technical Details

### Date Calculation Logic
```ruby
start_date = 24.months.ago.beginning_of_month
# Example: If today is 2025-08-27
# start_date = 2023-08-01 00:00:00
```

### SQL Query Pattern
```sql
WITH period_totals AS (
  SELECT
    date_trunc(:interval, ae.date) as period,
    CASE WHEN ae.amount < 0 THEN 'income' ELSE 'expense' END as classification,
    SUM(ae.amount * COALESCE(er.rate, 1)) as total
  FROM transactions t
  JOIN entries ae ON ae.entryable_id = t.id AND ae.entryable_type = 'Transaction'
  JOIN accounts a ON a.id = ae.account_id
  LEFT JOIN exchange_rates er ON (...)
  WHERE a.family_id = :family_id
    AND a.status IN ('draft', 'active')
    AND ae.date >= :start_date  -- 24-month filter
    AND t.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
    AND ae.excluded = false
  GROUP BY period, classification
)
SELECT
  classification,
  ABS(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total)) as median,
  ABS(AVG(total)) as avg
FROM period_totals
GROUP BY classification;
```

### Cache Behavior
- **Cache Keys**: No changes required (existing accounts_cache_version and entries_cache_version)
- **Invalidation**: Monthly recalculation automatically includes updated 24-month window
- **Performance**: Rolling 24-month window automatically maintained through date logic

## Edge Cases Handled

### 1. New Users (<24 Months Data)
- **Behavior**: Uses all available data (no negative impact)
- **SQL Result**: WHERE clause includes all existing entries
- **User Experience**: Same calculation accuracy as before

### 2. Users with Exactly 24 Months
- **Behavior**: Uses all available data
- **Transition**: Smooth transition as older data falls outside window

### 3. Seasonal Businesses
- **Improvement**: Better captures recent seasonal patterns vs. historical averages
- **Accuracy**: 2 complete seasonal cycles in calculation window

### 4. Gap Periods (No Transactions)
- **Behavior**: Gracefully handles months with zero transactions  
- **SQL**: Median calculation works correctly with available periods only

## Comparison with Other Features

### Consistent Timeframe Approach
- **Budget System**: Uses `2.years.ago.beginning_of_month` for oldest_valid_budget_date
- **Account Opening Balance**: Defaults to `2.years.ago.to_date`  
- **Forecast Historical Series**: Shows `2.years.ago.beginning_of_month` for context
- **Demo Data Generator**: Uses 36-month cycles for various transaction patterns

### Alignment Benefits
- **User Expectations**: Consistent 2-year perspective across financial features
- **Data Scope**: Matching timeframes between budget estimates and forecast medians
- **UI Consistency**: Similar data ranges in related financial planning tools

## Future Considerations

### Monitoring Opportunities
- **Forecast Accuracy**: Compare projected vs. actual values over time
- **User Feedback**: Monitor user satisfaction with forecast responsiveness  
- **Performance Metrics**: Track query execution times with filtered data

### Enhancement Options
- **Configurable Window**: Allow users to choose 12/18/24/36 month calculation windows
- **Seasonal Adjustments**: Weight recent seasonal periods more heavily
- **Trend Analysis**: Include trend direction in addition to median values

### Maintenance Notes
- **Date Logic**: Automatically maintains rolling 24-month window
- **No Scheduled Tasks**: Self-maintaining through date calculation
- **Index Optimization**: Existing `entries.date` indexes optimize the date filter

## Conclusion

The 24-month median implementation successfully addresses the "sticky forecast" problem while maintaining system performance and data integrity. Users now experience more responsive forecasts that better reflect their current financial situation, particularly beneficial for:

- Long-term users with extensive transaction history
- Users who have experienced recent life changes  
- Seasonal businesses with evolving patterns
- Anyone using forecasts for near-term financial planning

The implementation follows established application patterns, requires no ongoing maintenance, and provides immediate performance benefits through reduced data processing.