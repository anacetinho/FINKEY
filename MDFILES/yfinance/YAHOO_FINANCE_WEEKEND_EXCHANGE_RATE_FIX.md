# Yahoo Finance Weekend Exchange Rate Fix

## Problem Summary

CHF accounts were displaying **0 EUR values specifically on weekends**, causing significant issues with portfolio valuation and financial reporting. The problem occurred consistently on:

- August 9th (Saturday): CHF accounts showed 0 EUR
- August 24th (Sunday): CHF accounts showed 0 EUR  
- August 30th (Saturday): CHF accounts showed 0 EUR

## Root Cause Analysis

### Investigation Findings

1. **Yahoo Finance Service**: Working correctly - returns valid exchange rates even on weekends (using Friday's rate)
2. **Exchange Rate Storage**: **0.0 values were being stored in the database** for weekend dates instead of proper rates
3. **COALESCE Logic Flaw**: `COALESCE(er.rate, 1)` was using `0.0` instead of falling back to `1` because `0.0` is not NULL
4. **Import Process Bug**: `ExchangeRate::Importer` had a weekend handling bug that caused `nil` rates to be stored as `0.0`

### Technical Analysis

**Currency Conversion Logic:**
```sql
ae.amount * COALESCE(er.rate, 1)
```

**On weekends:**
- `er.rate` = `0.0` (from corrupted database records)
- `COALESCE(0.0, 1)` = `0.0` (because 0.0 is not NULL!)
- `CHF_amount * 0.0` = `0 EUR`

**The core issue**: `COALESCE` treats `0.0` as a valid rate, not a missing value, so it doesn't fall back to `1`.

## Implementation Solution

### Phase 1: Fix COALESCE Logic

**Updated SQL Pattern:**
```sql
-- OLD (problematic):
COALESCE(er.rate, 1)

-- NEW (fixed):
COALESCE(NULLIF(er.rate, 0), 1)
```

**Files Modified:**
- `app/models/concerns/amount_calculator.rb` - Core SQL logic used across the application
- `app/models/income_statement/family_stats.rb` - Family-level statistics
- `app/models/income_statement/category_stats.rb` - Category-level statistics  
- `app/models/transaction/search.rb` - Transaction search totals
- `app/models/balance/chart_series_builder.rb` - Balance chart calculations
- `test/models/concerns/amount_calculator_test.rb` - Updated test expectations

### Phase 2: Fix Existing Data

**Data Correction Using LOCF (Last Observation Carried Forward):**
```ruby
# Applied to all 0.0 exchange rates
zero_rates.group_by { |r| [r.from_currency, r.to_currency] }.each do |(from, to), rates|
  rates.each do |rate|
    previous_rate = ExchangeRate
      .where(from_currency: from, to_currency: to)
      .where('date < ?', rate.date)
      .where('rate > 0')
      .order(date: :desc)
      .first
      
    if previous_rate
      rate.update(rate: previous_rate.rate)
    end
  end
end
```

**Results:**
- Fixed 5 exchange rates using LOCF
- August 9th: `0.0` → `1.062299966812133`
- August 10th: `0.0` → `1.062299966812133`
- August 23rd: `0.0` → `1.064599990844726`
- August 24th: `0.0` → `1.064599990844726`
- August 30th: `0.0` → `1.068400025367736`

### Phase 3: Fix ExchangeRate::Importer Weekend Bug

**Root Cause in Importer:**
- Yahoo Finance bulk API (`fetch_exchange_rates`) doesn't return weekend data
- Yahoo Finance single API (`fetch_exchange_rate`) does return weekend data (with Friday's rate)
- Importer was looking for `provider_rates[saturday_date]` but only had `provider_rates[friday_date]`
- When Saturday data wasn't found, `nil` was stored as `0.0`

**Solution Applied:**
```ruby
# In ExchangeRate::Importer#import_provider_rates
gapfilled_rates = effective_start_date.upto(end_date).map do |date|
  db_rate_value = db_rates[date]&.rate
  provider_rate_value = provider_rates[date]&.rate
  
  # NEW: If no provider rate for exact date, look for most recent (for weekends/holidays)
  if provider_rate_value.nil? && provider_rates.any?
    latest_provider_rate = provider_rates.select { |pd, _| pd <= date }.max_by { |pd, _| pd }&.last
    provider_rate_value = latest_provider_rate&.rate
  end
  
  chosen_rate = if clear_cache
    provider_rate_value || db_rate_value
  else
    db_rate_value || provider_rate_value
  end
  
  # Existing LOCF logic
  if chosen_rate.nil?
    chosen_rate = prev_rate_value
  end
  
  prev_rate_value = chosen_rate
  
  {
    from_currency: from,
    to_currency: to,
    date: date,
    rate: chosen_rate
  }
end
```

**Additional Fix:**
```ruby
# Fixed start_rate_value method to return numeric value instead of Rate object
def start_rate_value
  provider_rate_value = provider_rates.select { |date, _| date <= start_date }.max_by { |date, _| date }&.last
  db_rate_value = db_rates[start_date]&.rate
  provider_rate_value&.rate || db_rate_value  # Added &.rate to extract numeric value
end
```

### Phase 4: Database Validation (Future)

**Migration Created (Deferred):**
```ruby
class AddPositiveRateConstraintToExchangeRates < ActiveRecord::Migration[7.2]
  def change
    execute <<-SQL
      ALTER TABLE exchange_rates 
      ADD CONSTRAINT positive_rate_check 
      CHECK (rate > 0);
    SQL
  end
end
```

*Note: Migration deferred due to legacy 0.0 rates from 2012 that would need cleanup first.*

## Verification Results

### Before Fix
```
CHF Account Values on Weekends: 0 EUR (BROKEN)
Exchange Rate Database Values: 0.0 for weekend dates
Importer Behavior: Claims success but stores 0.0 rates
```

### After Fix
```
CHF Account Values:
- 83 CHF = 88.68 EUR ✅
- 11,137 CHF = 11,898.77 EUR ✅  
- 46,467 CHF = 49,645.34 EUR ✅

Exchange Rate Database Values: 
- Weekend rates now use proper LOCF values (1.068+ range)
- No more 0.0 rates being stored

Importer Behavior: 
- Successfully imports weekend rates using Friday's data
- Proper LOCF gap-filling for missing dates
```

### Test Validation
```ruby
# Test SQL with improved COALESCE logic
result = ActiveRecord::Base.connection.execute("
  SELECT 
    100 * COALESCE(NULLIF(er.rate, 0), 1) as converted_amount,
    er.rate as exchange_rate
  FROM exchange_rates er 
  WHERE er.from_currency = 'CHF' 
    AND er.to_currency = 'EUR' 
    AND er.date = '2025-08-30'
")

# Result: 100 CHF = 106.84 EUR (rate: 1.068400025367736)
# SUCCESS: No more 0 EUR values!
```

## Architecture Impact

### Files Changed

**Core Logic:**
- `app/models/concerns/amount_calculator.rb` - Central SQL logic for currency conversion
- `app/models/exchange_rate/importer.rb` - Weekend rate import handling

**Income Statement Calculations:**
- `app/models/income_statement/family_stats.rb` - Family statistics with currency conversion
- `app/models/income_statement/category_stats.rb` - Category statistics with currency conversion

**Balance & Search:**
- `app/models/balance/chart_series_builder.rb` - Chart data with currency conversion
- `app/models/transaction/search.rb` - Search totals with currency conversion

**Testing:**
- `test/models/concerns/amount_calculator_test.rb` - Updated test expectations

### Deployment Considerations

**File Synchronization:**
- Changes made to local files must be copied to Docker container
- Use `docker cp` to sync files after modifications
- Clear Rails cache after updates: `Rails.cache.clear`

**Data Migration:**
- Weekend exchange rates automatically fixed using LOCF
- No manual intervention needed for future weekend rates
- Existing account balances will display correctly immediately

## Future Enhancements

### Monitoring
1. **Exchange Rate Alerts**: Monitor for any future 0.0 rate insertions
2. **Weekend Rate Validation**: Automated tests for weekend import scenarios
3. **Data Quality Checks**: Regular validation of exchange rate continuity

### Performance
1. **Exchange Rate Caching**: Consider caching frequently accessed rates
2. **Batch Updates**: Optimize bulk exchange rate operations
3. **Index Optimization**: Ensure optimal query performance for currency conversion

### Robustness
1. **Provider Fallback**: Enhanced fallback logic when Yahoo Finance is unavailable  
2. **Rate Gap Detection**: Automated detection of missing exchange rate periods
3. **Historical Data Backfill**: Tools for importing historical rate gaps

## Conclusion

The Yahoo Finance weekend exchange rate issue has been comprehensively resolved through:

1. **Root Cause Identification**: 0.0 database values causing incorrect COALESCE behavior
2. **Systematic Fix**: Updated all currency conversion logic to handle 0.0 as NULL
3. **Data Correction**: Applied LOCF to existing weekend rates
4. **Import Process Fix**: Enhanced weekend rate handling in the importer
5. **Validation**: Confirmed CHF accounts now show correct EUR values

**Impact**: CHF portfolio values are now accurate on weekends, eliminating the periodic "portfolio crash to 0" issue that was affecting financial reporting and user confidence.

**Reliability**: Future weekend imports will automatically use proper LOCF logic, ensuring continuous accurate currency conversion regardless of Yahoo Finance's weekend data availability.