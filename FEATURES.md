# Enhanced Features

This community-maintained fork includes several major enhancements over the original Maybe Finance app, providing improved functionality for personal finance management.

## 🔄 Yahoo Finance Integration

**Replaces discontinued Synth API with reliable Yahoo Finance data source**

### What's New
- **Real-time Price Updates**: Direct integration with Yahoo Finance for current security prices
- **International Market Support**: Supports US, European, and Asian exchanges
- **Simplified Ticker Entry**: Direct symbol input instead of complex search functionality
- **Manual Price Control**: Administrator-controlled price updates through settings interface
- **Robust Error Handling**: Graceful fallback to other providers if Yahoo Finance fails

### Supported Markets
- **US**: NASDAQ, NYSE (AAPL, GOOGL, TSLA, MSFT)
- **London**: LSE (VOD.L, BP.L, LLOY.L)
- **Amsterdam**: Euronext (ASML.AS, RDSA.AS)
- **Paris**: Euronext (LVMH.PA, SAN.PA)
- **Frankfurt**: XETRA (SAP.DE, DAI.DE)
- **Switzerland**: SIX (NESN.SW, NOVN.SW)

### Benefits
- ✅ No more 30+ second search delays
- ✅ Reliable price data from established provider
- ✅ Clean separation of concerns with service layer architecture
- ✅ Docker-integrated Python environment for yfinance library

[📖 Full Documentation](docs/features/yahoo-finance.md)

---

## 📊 Enhanced 24-Month Forecasting

**More responsive financial forecasts using rolling 24-month median calculations**

### What's New
- **24-Month Rolling Window**: Uses only the last 24 months of data for median calculations
- **Responsive Forecasts**: Recent financial changes have greater impact on projections
- **Better Seasonal Patterns**: Captures current seasonal trends instead of historical averages
- **Performance Improvements**: 26% reduction in data processing for typical users

### Problem Solved
The original system used ALL historical data for forecasting, which meant:
- Users with extensive history saw "sticky" forecasts that didn't adapt to recent changes
- Old seasonal patterns from years ago influenced current projections
- Recent life events (job changes, lifestyle changes) had minimal forecast impact

### Benefits
- ✅ Forecasts adapt quickly to income/expense changes
- ✅ More relevant for short to medium-term financial planning
- ✅ Better seasonal pattern recognition for current circumstances
- ✅ Improved performance with smaller datasets

### Use Cases
- **Long-term Users**: Those with 5+ years of transaction history
- **Life Changes**: Users experiencing recent income or expense pattern changes
- **Seasonal Businesses**: Businesses with evolving seasonal patterns
- **Financial Planning**: Anyone using forecasts for near-term budgeting

[📖 Full Documentation](docs/features/enhanced-forecasting.md)

---

## 💰 Expense Reimbursement Tracking

**Proper accounting for reimbursable business expenses**

### What's New
- **Reimbursement Categories**: Special category flag for tracking reimbursable expenses
- **Accurate Net Worth**: Account balances increase with reimbursements
- **Budget Integration**: Shows net expense amounts after reimbursements
- **Forecasting Support**: Uses combined monthly totals for accurate projections

### How It Works
1. **Flag Categories**: Mark expense categories as "allows negative expenses"
2. **Record Expenses**: Enter business expenses normally (e.g., €600)
3. **Record Reimbursements**: Enter reimbursements as positive amounts (e.g., €250)
4. **Automatic Calculation**: System shows net expense (€350) and increases net worth by reimbursement

### Business Logic
- **Double-Entry Compliance**: Maintains proper accounting principles
- **Balance Calculations**: Reimbursements treated as account inflows
- **Expense Classification**: All transactions remain classified as expenses
- **Monthly Aggregation**: Combines expenses and reimbursements for accurate medians

### Benefits
- ✅ Accurate net worth calculations reflecting reimbursements
- ✅ Realistic budget expenses showing actual out-of-pocket costs
- ✅ Improved forecasting using net monthly expense amounts
- ✅ Clear audit trail for all reimbursement transactions

### Example Scenarios
- **Business Expenses**: Track meals, travel, supplies with employer reimbursement
- **Partial Reimbursements**: Handle cases where only part of expense is reimbursed
- **Multiple Categories**: Set up different reimbursement categories for different purposes

[📖 Full Documentation](docs/features/expense-reimbursement.md)

---

## 🚀 Getting Started

### For Self-Hosting
1. **Build the Enhanced Container**: `docker-compose build --no-cache`
2. **Start the Application**: `docker-compose up -d`
3. **Access the App**: Visit http://localhost:3000

### For Development
1. **Clone the Repository**: `git clone [your-fork-url]`
2. **Follow Setup Guide**: See [Development Setup](README.md#local-development-setup)
3. **Read Documentation**: Explore individual feature docs in `/docs/features/`

---

## 📚 Documentation

### Feature Guides
- [Yahoo Finance Integration](docs/features/yahoo-finance.md)
- [Enhanced Forecasting](docs/features/enhanced-forecasting.md)
- [Expense Reimbursement](docs/features/expense-reimbursement.md)

### Setup & Configuration
- [Docker Hosting Guide](docs/hosting/docker.md)
- [Development Setup](README.md#local-development-setup)

### API Documentation
- [Chat API](docs/api/chats.md)

---

## 🤝 Contributing

This is a community-maintained fork. Contributions are welcome! See our [Contributing Guidelines](CONTRIBUTING.md) for details on how to get involved.

---

## ⚖️ License & Attribution

This fork is based on the original Maybe Finance app but is **NOT affiliated with or endorsed by Maybe Finance Inc.**

Licensed under the [AGPLv3 License](LICENSE). "Maybe" is a trademark of Maybe Finance Inc.