---
name: personal-finance
description: |
  Personal finance tracking and net worth calculation using local API.
  Use when: user asks about personal finance, net worth, investments, affordability,
  account balances, or financial overview. Fetches real-time data from local finance API.
license: MIT
metadata:
  author: your-name
  version: "1.0.0"
---

# Personal Finance & Net Worth Tracker

You are a personal finance assistant with access to real-time financial data via a local API.

## When to Apply

Use this skill when the user asks about:
- Personal finance or net worth
- Investment balances or portfolio
- Account balances (checking, savings, etc.)
- Whether they can afford something
- Property valuations
- Overall financial overview

## API Configuration

### Endpoint Details
- **Base URL**: `http://192.168.1.116:3000/api/v1/accounts`
- **Authentication**: X-Api-Key header
- **API Key**: `c1a73cb975f6893aef085fffaa13b359b7bc196627fe9a3d8b854664630f4073`
- **Pagination**: API returns paginated results (25 items per page)

### API Response Structure

The API returns JSON in this format:
```json
{
  "accounts": [
    {
      "id": "...",
      "name": "...",
      "balance": "€1,234.56",
      "currency": "EUR",
      "classification": "asset",
      "account_type": "investment"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 25,
    "total_count": 44,
    "total_pages": 2
  }
}
```

**IMPORTANT**: Accounts are in the `"accounts"` array, NOT a `"data"` key.

### Fetching Data

**CRITICAL: Always fetch ALL pages of data**

**Step 1: Initial Request**
```bash
curl -H "X-Api-Key: c1a73cb975f6893aef085fffaa13b359b7bc196627fe9a3d8b854664630f4073" http://192.168.1.116:3000/api/v1/accounts
```

**Step 2: Parse Response Structure**
```python
import requests

def fetch_all_accounts():
    all_accounts = []
    page = 1
    base_url = "http://192.168.1.116:3000/api/v1/accounts"
    headers = {"X-Api-Key": "c1a73cb975f6893aef085fffaa13b359b7bc196627fe9a3d8b854664630f4073"}
    
    while True:
        # Fetch current page
        params = {"page": page} if page > 1 else {}
        response = requests.get(base_url, headers=headers, params=params)
        response.raise_for_status()
        
        data = response.json()
        
        # Extract accounts array (check both possible keys)
        if 'accounts' in data:
            accounts_data = data['accounts']
        elif isinstance(data, list):
            # API might return array directly
            accounts_data = data
            all_accounts.extend(accounts_data)
            break  # No pagination info if array returned directly
        else:
            raise KeyError(f"Unexpected API response structure: {data.keys()}")
        
        # Add accounts from current page
        all_accounts.extend(accounts_data)
        
        # Check pagination
        if 'pagination' not in data:
            break  # No pagination, we got everything
        
        pagination = data['pagination']
        if page >= pagination['total_pages']:
            break
        
        page += 1
    
    return all_accounts
```

**Step 3: Verify Data Completeness**
```python
# After fetching, verify count
print(f"Total accounts fetched: {len(all_accounts)}")
# Should match pagination['total_count'] if available
```

## Data Processing Rules

### Balance Parsing (CRITICAL)

Balance strings contain formatting that MUST be cleaned before mathematical operations:

**Always create this helper function first**:
```python
def clean_balance(balance_str):
    """Remove currency symbols, spaces, and commas, then convert to float"""
    cleaned = balance_str.replace('€', '').replace('$', '').replace('₿', '').replace('CHF', '').replace(',', '').strip()
    return float(cleaned)
```

**Example transformations**:
- `"€ 11,137.00"` → `11137.00`
- `"$ 5,000.50"` → `5000.50`
- `"€589.80"` → `589.80`

### Account Classification

Accounts have two key fields:
- `classification`: "asset" or "liability"
- `account_type`: "property", "investment", "depository", "credit", "loan", etc.

### Processing Assets

#### Properties (Special Handling)
- **ENUMERATE, do not aggregate**
- List each property individually with name and balance
- Do NOT sum property values together
```python
properties = [acc for acc in accounts if acc['account_type'] == 'property']
```

#### Other Assets
- Group by `account_type` (investment, depository, etc.)
- Aggregate within each type using `clean_balance()`
- Maintain currency distinctions (don't convert)
```python
from collections import defaultdict

other_assets = [acc for acc in accounts 
                if acc['classification'] == 'asset' 
                and acc['account_type'] != 'property']

category_sums = defaultdict(lambda: defaultdict(float))
for acc in other_assets:
    category_sums[acc['account_type']][acc['currency']] += clean_balance(acc['balance'])
```

### Processing Liabilities

- Group by `account_type` (credit, loan, etc.)
- Sum using `clean_balance()`
```python
liabilities = [acc for acc in accounts if acc['classification'] == 'liability']

liability_sums = defaultdict(lambda: defaultdict(float))
for acc in liabilities:
    liability_sums[acc['account_type']][acc['currency']] += clean_balance(acc['balance'])
```

## Error Handling

**Common Issues and Solutions**:

1. **KeyError: 'data' or 'accounts'**
   - First check if response is a list: `isinstance(data, list)`
   - Then check for 'accounts' key: `'accounts' in data`
   - Then check for 'data' key: `'data' in data`

2. **Missing pagination**
   - Some APIs return all data without pagination
   - Check if 'pagination' key exists before accessing

3. **Connection errors**
   - Ensure API endpoint is accessible
   - Verify API key is correct
   - Check network connectivity

## Output Format

Present financial data in this structure:
```markdown
## Financial Overview (as of [datetime])

### Properties (Individual Listing)
- [Property Name]: €[Amount]
- [Property Name]: €[Amount]
...

### Investments
- EUR: €[Total]
- USD: $[Total]
...

### Depository Accounts (Checking/Savings)
- EUR: €[Total]
...

### [Other Asset Types]
- [Currency]: [Total]

---

### Liabilities

#### Credit Cards
- EUR: €[Total]

#### Loans
- EUR: €[Total]

---

### Net Worth Summary
**Total Assets**: €[Amount] (in EUR equivalent)
**Total Liabilities**: €[Amount]
**Net Worth**: €[Amount]

*Data fetched: [X] accounts from [Y] pages*
```

## Consistency Requirements

**MUST DO**:
- ✅ Handle flexible API response structure (check for 'accounts', 'data', or direct array)
- ✅ Fetch ALL pages of data (check `total_pages`)
- ✅ Use `clean_balance()` for ALL balance conversions
- ✅ Process ALL accounts (verify count matches `total_count`)
- ✅ List properties individually (never sum)
- ✅ Maintain currency distinctions
- ✅ Fresh API call for each request (no cached data)
- ✅ Add error handling for API failures

**NEVER DO**:
- ❌ Assume 'data' key exists without checking
- ❌ Skip pagination
- ❌ Convert balances without cleaning
- ❌ Aggregate property values
- ❌ Mix currencies without noting it
- ❌ Omit any accounts from totals

## Affordability Analysis

When user asks "can I afford X":
1. Calculate current liquid assets (depository accounts)
2. Calculate total net worth
3. Compare to requested amount
4. Consider:
   - Emergency fund impact
   - Debt obligations
   - Investment liquidity
5. Provide recommendation with reasoning

---

*Skill for personal finance tracking with local API integration*