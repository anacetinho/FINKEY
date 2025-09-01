# Documentation Index

Welcome to the documentation for the Community-Enhanced Personal Finance App! This enhanced fork of Maybe Finance includes several powerful new features while maintaining full compatibility with the original.

## 🚀 Quick Start

- **[Main README](../README.md)** - Project overview and quick setup
- **[Features Overview](../FEATURES.md)** - Complete guide to all enhancements
- **[Release Notes](../RELEASE_NOTES.md)** - What's new in this version
- **[Contributing Guide](../CONTRIBUTING.md)** - How to contribute to the project

## 📋 Enhanced Features

### 🔄 Yahoo Finance Integration
- **[Feature Documentation](features/yahoo-finance.md)** - Complete feature overview
- **[Setup Guide](setup/yahoo-finance-setup.md)** - Installation and configuration

### 📊 Enhanced 24-Month Forecasting
- **[Feature Documentation](features/enhanced-forecasting.md)** - How the improved forecasting works

### 💰 Expense Reimbursement Tracking
- **[Feature Documentation](features/expense-reimbursement.md)** - Business expense reimbursement system

## 🛠️ Setup & Installation

- **[Migration Guide](setup/migration-guide.md)** - Upgrade from original Maybe Finance
- **[Yahoo Finance Setup](setup/yahoo-finance-setup.md)** - Configure price data integration
- **[Docker Hosting](hosting/docker.md)** - Self-hosting with Docker (original guide)

## 🔧 Troubleshooting & Support

- **[Common Issues](troubleshooting/common-issues.md)** - Solutions to frequent problems
- **[Debug Guide](troubleshooting/common-issues.md#getting-support)** - How to collect logs and report issues

## 🔌 API Documentation

- **[Chat API](api/chats.md)** - AI chat functionality (original documentation)

## 📁 Documentation Structure

```
docs/
├── README.md                          # This file
├── features/                          # Feature documentation
│   ├── yahoo-finance.md              # Yahoo Finance integration
│   ├── enhanced-forecasting.md       # 24-month forecasting
│   └── expense-reimbursement.md      # Expense reimbursement
├── setup/                            # Setup and configuration
│   ├── migration-guide.md            # Migration from original
│   └── yahoo-finance-setup.md        # Yahoo Finance setup
├── troubleshooting/                  # Help and debugging
│   └── common-issues.md              # Common problems and solutions
├── hosting/                          # Self-hosting guides
│   └── docker.md                     # Docker setup (original)
└── api/                              # API documentation
    └── chats.md                      # Chat API (original)
```

## 🎯 Getting Help

### For Users
1. **Setup Issues**: Check [Migration Guide](setup/migration-guide.md) or [Yahoo Finance Setup](setup/yahoo-finance-setup.md)
2. **Feature Questions**: Read the relevant feature documentation in `/features/`
3. **Problems**: Look in [Common Issues](troubleshooting/common-issues.md)
4. **Still Stuck**: Open a GitHub issue with detailed information

### For Developers
1. **Contributing**: Start with [Contributing Guide](../CONTRIBUTING.md)
2. **Development Setup**: See [README.md](../README.md#local-development-setup)
3. **Code Conventions**: Read [CLAUDE.md](../CLAUDE.md) for development guidelines
4. **Feature Development**: Check [FEATURES.md](../FEATURES.md) for enhancement ideas

### For Self-Hosters
1. **Docker Setup**: See [Docker Hosting Guide](hosting/docker.md)
2. **Migration**: Use [Migration Guide](setup/migration-guide.md) to upgrade
3. **Configuration**: Check feature-specific setup guides
4. **Troubleshooting**: Use [Common Issues Guide](troubleshooting/common-issues.md)

## 🔍 What's Different from Original Maybe?

This community fork adds three major enhancements:

| Feature | Original Maybe | Community Fork |
|---------|----------------|----------------|
| **Price Data** | Synth API (discontinued) | Yahoo Finance integration |
| **Forecasting** | All historical data | Rolling 24-month window |
| **Reimbursements** | Not supported | Full expense reimbursement tracking |
| **Setup** | Ruby/Rails only | Ruby/Rails + Python (for yfinance) |
| **Updates** | Automatic (when available) | Manual administrator control |

## 🚦 Status & Roadmap

### Current Status
- ✅ **Stable**: All three enhanced features are production-ready
- ✅ **Tested**: Comprehensive test coverage for new functionality
- ✅ **Documented**: Complete user and developer documentation
- ✅ **Secure**: Security scanning and safe practices implemented

### Future Enhancements
- **Configurable Forecast Windows**: User-selectable calculation periods
- **Batch Price Updates**: Performance improvements for large portfolios
- **Enhanced Reimbursement Matching**: Link specific expenses to reimbursements
- **Additional Data Sources**: Support for more financial data providers

## ⚖️ License & Attribution

This community fork is based on Maybe Finance v0.6.0 and is **NOT affiliated with or endorsed by Maybe Finance Inc.**

- **License**: [AGPLv3](../LICENSE)
- **Original Work**: Copyright Maybe Finance Inc.
- **Community Enhancements**: Licensed under same AGPLv3 terms
- **Trademark**: "Maybe" is a trademark of Maybe Finance Inc.

## 🙏 Acknowledgments

- **Maybe Finance Team**: For creating the original open-source foundation
- **Community Contributors**: For testing, feedback, and improvements
- **Open Source Projects**: yfinance, Rails, PostgreSQL, and many others

---

*Last updated: Community Fork v1.0.0*