# Release Notes

## Community Fork v1.0.0 - Enhanced Features

*Based on Maybe Finance v0.6.0*

This is the first release of the community-maintained fork of Maybe Finance, featuring significant enhancements while maintaining full compatibility with the original application.

### 🚀 What's New

#### Yahoo Finance Integration
- **Replaced Synth API**: Migrated from discontinued Synth API to reliable Yahoo Finance
- **International Markets**: Support for US, European, and Asian exchanges
- **Simplified Entry**: Direct ticker symbol input without search delays
- **Manual Control**: Administrator-controlled price updates via settings
- **Docker Integration**: Python and yfinance dependencies included in container

#### Enhanced 24-Month Forecasting
- **Rolling Window**: Uses last 24 months instead of all historical data
- **Responsive Forecasts**: Adapts quickly to recent financial changes
- **Better Performance**: 26% reduction in data processing (typical case)
- **Seasonal Patterns**: Captures current trends vs. historical averages

#### Expense Reimbursement Tracking
- **Business Expenses**: Track reimbursable business expenses properly
- **Accurate Accounting**: Maintains double-entry accounting principles
- **Budget Integration**: Shows net expenses after reimbursements
- **Net Worth Impact**: Correctly reflects reimbursement benefits

### 🔧 Technical Improvements

#### Architecture Enhancements
- **Service Layer**: Clean separation for Yahoo Finance integration
- **Provider System**: Extensible provider architecture with fallback support
- **Error Handling**: Comprehensive exception catching and graceful degradation
- **Security**: Secure Python script execution with input sanitization

#### Database Optimizations
- **Efficient Queries**: Optimized median calculations with date filtering
- **Index Usage**: Better utilization of existing database indexes
- **Cache Improvements**: Reduced query load with smart caching

#### Docker Improvements
- **Python Support**: Integrated Python 3 environment with financial libraries
- **Dependency Management**: Automated installation of required packages
- **Build Optimization**: Efficient layer caching for faster builds

### 📊 Performance Improvements

- **Faster Forecasting**: 24-month window reduces calculation time
- **Efficient Price Updates**: Manual updates prevent rate limiting issues
- **Optimized Queries**: Better database query performance
- **Reduced Memory Usage**: Smaller datasets for statistical calculations

### 🛠️ Breaking Changes

#### Investment Workflow
- **Ticker Entry**: No more complex symbol search - type ticker directly
- **Price Updates**: Manual updates instead of automatic background updates
- **Provider Priority**: Yahoo Finance becomes primary security data provider

#### Forecasting Behavior  
- **Data Window**: Forecasts now use 24-month rolling window
- **Calculation Changes**: Median values may differ from previous versions
- **Cache Invalidation**: Existing forecast cache will be recalculated

### 🔄 Migration Guide

This release maintains full database compatibility. Existing installations can upgrade in-place:

1. **Backup Data**: Export your data before upgrading
2. **Build Container**: `docker-compose build --no-cache`
3. **Run Migrations**: `docker-compose exec web rails db:migrate`
4. **Configure Features**: Enable Yahoo Finance in Settings → Hosting

See [Migration Guide](docs/setup/migration-guide.md) for detailed instructions.

### 📚 Documentation

#### New Documentation
- [Features Overview](FEATURES.md) - Complete guide to all enhancements
- [Yahoo Finance Setup](docs/setup/yahoo-finance-setup.md) - Setup and configuration
- [Migration Guide](docs/setup/migration-guide.md) - Upgrade from original Maybe
- [Troubleshooting](docs/troubleshooting/common-issues.md) - Common issues and solutions

#### Updated Documentation
- [README](README.md) - Updated with fork information and features
- [CONTRIBUTING](CONTRIBUTING.md) - Community contribution guidelines

### 🐛 Bug Fixes

- **Balance Calculations**: Fixed reimbursement impact on account balances
- **Median Statistics**: Corrected combined monthly total calculations
- **Error Handling**: Improved error messages and recovery
- **Container Builds**: Resolved dependency installation issues

### ⚡ Known Issues

- **First-Time Setup**: Python dependencies require container rebuild
- **Large Datasets**: Price updates for 100+ securities may take several minutes
- **Symbol Validation**: Some exotic securities may not be available in Yahoo Finance

### 🔮 Future Roadmap

#### Planned Enhancements
- **Configurable Forecast Windows**: Allow users to choose calculation periods
- **Batch Price Updates**: Improve performance for large portfolios
- **Enhanced Reimbursement**: Link expenses to specific reimbursements
- **Additional Data Sources**: Support for more financial data providers

#### Community Features
- **Plugin System**: Framework for community-contributed features
- **API Extensions**: Enhanced API for third-party integrations
- **Mobile Improvements**: Better mobile experience and offline support

### 🙏 Acknowledgments

This community fork is based on the excellent work by the Maybe Finance team. Special thanks to:
- **Maybe Finance Team**: For creating the original open-source foundation
- **Community Contributors**: For testing, feedback, and contributions
- **Open Source Projects**: yfinance, Rails, and other dependencies

### ⚖️ License

This software is distributed under the [AGPLv3 License](LICENSE), same as the original Maybe Finance app.

**Disclaimer**: This is a community-maintained fork and is **NOT affiliated with or endorsed by Maybe Finance Inc.** "Maybe" is a trademark of Maybe Finance Inc.

### 📞 Support

- **Documentation**: See `/docs/` folder for comprehensive guides  
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Community**: Join discussions for help and feature ideas
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines

---

## Upgrade Instructions

### From Original Maybe v0.6.0

1. **Backup your data**:
   ```bash
   docker-compose exec db pg_dump -U maybe_user maybe_production > backup.sql
   ```

2. **Stop current installation**:
   ```bash
   docker-compose down
   ```

3. **Update to community fork**:
   ```bash
   git remote add fork https://github.com/[username]/[repository].git
   git fetch fork
   git merge fork/main
   ```

4. **Build enhanced container**:
   ```bash
   docker-compose build --no-cache
   ```

5. **Start and migrate**:
   ```bash
   docker-compose up -d
   docker-compose exec web rails db:migrate
   ```

6. **Configure new features**:
   - Go to Settings → Hosting
   - Enable Yahoo Finance integration
   - Test price updates

### Verification Steps

After upgrade, verify that:
- [ ] Application starts without errors
- [ ] All accounts and transactions are intact  
- [ ] Yahoo Finance price updates work
- [ ] Forecasts reflect recent financial patterns
- [ ] Expense reimbursement categories function properly

For detailed migration assistance, see [Migration Guide](docs/setup/migration-guide.md).