# Yahoo Finance Weekend Exchange Rate Investigation

## Problem Summary
CHF accounts display 0 EUR values specifically on weekends:
- August 9th (Saturday): 0 EUR
- August 24th (Sunday): 0 EUR  
- August 30th (Saturday): 0 EUR

## Investigation Results

### 1. Exchange Rate Data Analysis
**Database Query Results:**
```
2025-08-08: 1.062299966812133
2025-08-09: 0.0                  ← Saturday (PROBLEM)
2025-08-10: 0.0                  ← Sunday  
2025-08-11: 1.062970042228698    ← Monday (working)
...
2025-08-23: 0.0                  ← Friday
2025-08-24: 0.0                  ← Sunday (PROBLEM)
2025-08-25: 1.065000057220459    ← Monday (working)
...
2025-08-29: 1.069100022315979    ← Thursday (working)
2025-08-30: 0.0                  ← Saturday (PROBLEM - TODAY)
```

**Key Finding**: Exchange rates are being **stored as 0.0** in the database for weekend dates, not missing entirely.

### 2. Yahoo Finance Service Status
- **Provider Active**: `Provider::YahooFinance` is correctly configured
- **Service Working**: YahooFinanceService initializes successfully
- **API Response**: Returns valid data for weekdays
  ```
  Success: {from: "CHF", to: "EUR", rate: 1.0684000253677368, date: Fri, 29 Aug 2025}
  ```
- **Weekend Behavior**: On Saturday (today), Yahoo Finance returns Friday's rate but import process stores it as 0.0

### 3. Import Process Investigation
**Manual Import Test Results:**
- Before import: `0.0 (date: 2025-08-30)`
- Import attempted: `2 rates imported` 
- After import: `0.0 (date: 2025-08-30)` (STILL ZERO!)

**Critical Finding**: The import process claims success ("2 rates imported") but the weekend rate remains 0.0, indicating a **bug in the import logic**.

### 4. Data Pattern Analysis
- **Weekdays**: Proper exchange rates (1.06-1.07 range)
- **Weekends**: Systematically stored as `0.0`
- **Gap Filling**: LOCF (Last Observation Carried Forward) is NOT working
- **Import Claims Success**: The importer reports successful imports but data is corrupted

## Root Cause Identification

**Primary Issue**: The `ExchangeRate::Importer` has a bug that causes weekend rates to be stored as `0.0` instead of using the LOCF strategy.

**Technical Analysis:**
1. Yahoo Finance service works correctly and returns valid rates
2. The import process runs and claims success
3. However, weekend dates get stored as `0.0` instead of the last known good rate
4. This causes `COALESCE(er.rate, 1)` to use `0.0`, making CHF amounts become 0 EUR

## Impact on CHF Accounts

When the system calculates CHF account values in EUR:
```sql
ae.amount * COALESCE(er.rate, 1)
```

On weekends:
- `er.rate` = `0.0` (from corrupted database records)
- `COALESCE(0.0, 1)` = `0.0` (because 0.0 is not NULL!)
- `CHF_amount * 0.0` = `0 EUR`

**The bug**: `COALESCE` treats `0.0` as a valid rate, not a missing value, so it doesn't fall back to `1`.

## Recommended Fixes

### Immediate Fix (Data Correction)
1. **Update Zero Rates**: Change all `0.0` exchange rates to proper LOCF values
2. **Recalculate Balances**: Trigger balance recalculation for affected dates

### Code Fixes Required

#### 1. Fix COALESCE Logic
Change from:
```sql
COALESCE(er.rate, 1)
```
To:
```sql
COALESCE(NULLIF(er.rate, 0), 1)  -- Treat 0 as NULL for fallback
```

#### 2. Fix Exchange Rate Importer
The `ExchangeRate::Importer` needs debugging to understand why it's storing `0.0` instead of using LOCF for weekends.

#### 3. Add Validation
Add database constraint to prevent `0.0` rates:
```sql
ALTER TABLE exchange_rates ADD CONSTRAINT positive_rate CHECK (rate > 0);
```

## Testing Verification
After fixes, verify:
1. Weekend CHF account balances show correct EUR values
2. Exchange rate table has no more `0.0` values
3. LOCF strategy works correctly for gaps
4. Import process handles weekends properly

## Conclusion
The issue is **NOT** that Yahoo Finance fails on weekends, but that the import process has a bug that stores `0.0` rates instead of using gap-filling logic. The `COALESCE` function then uses these zero rates instead of falling back to `1`, causing CHF amounts to become 0 EUR.