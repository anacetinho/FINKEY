
# FinKey: Your Personal Finance Command Center 🗝️💰

**A powerful, self-hosted personal finance application with advanced features**

> [!NOTE]
> **Legal Notice**: This project is a fork of Maybe Finance and is licensed under the AGPLv3. This fork is **not affiliated with or endorsed by** Maybe Finance Inc. "Maybe" is a trademark of Maybe Finance Inc.

## 🚀 What Makes FinKey Special

FinKey builds upon the solid foundation of Maybe Finance with enhanced features:

- **🤖 Flexible AI Assistant** - Configure AI directly in the UI! Choose between OpenAI or run your own local LLM (Ollama, LM Studio, etc.) without editing environment files
- **🌍 Yahoo Finance Integration** - Real-time exchange rates for accurate multi-currency tracking
- **💸 Advanced Expense Reimbursement System** - Handle complex transaction scenarios with ease
- **⚡ Enhanced Docker Setup** - Improved deployment and development experience
- **📊 Extended Forecasting** - Advanced financial projections and analytics

## 🚀 Quick Start - One-Click Setup!

FinKey is designed to be self-hosted, giving you complete control over your financial data.

### Windows Users
```batch
git clone https://github.com/your-username/finkey.git
cd finkey
setup.bat
```

### Linux/macOS Users
```bash
git clone https://github.com/your-username/finkey.git
cd finkey
chmod +x setup.sh
./setup.sh
```

**That's it!** The setup script handles everything automatically:
- ✅ Checks Docker installation
- ✅ Creates configuration files
- ✅ Downloads and builds all services
- ✅ Starts your FinKey instance
- ✅ Opens http://localhost:3000 in your browser

> **⏳ Note**: On first startup, it may take 2-3 minutes for the application to become available at `localhost:3000` due to Docker container initialization. If you experience delays, you can also access the app using your local IP address (e.g., `http://192.168.1.xxx:3000`) which typically loads faster.

### Manual Setup (Advanced Users)
```bash
git clone https://github.com/your-username/finkey.git
cd finkey
cp .env.example .env
# Edit .env with your settings
docker-compose up -d
```

**📚 Detailed hosting guide**: [Docker Self-Hosting Documentation](docs/hosting/docker.md)
**🔐 Security considerations**: [Security Guide](MDFILES/SECURITY.md)

## 🛠️ Local Development Setup

**If you're looking to self-host FinKey, use the Docker setup above instead.**

The instructions below are for developers who want to contribute to FinKey.

### Requirements

- See `.ruby-version` file for required Ruby version
- PostgreSQL >9.3 (ideally, latest stable version)
- Node.js and npm for asset compilation

### Development Setup

```bash
git clone [your-repo-url]
cd finkey
cp .env.local.example .env.local
bin/setup
bin/dev

# Optionally, load demo data
rake demo_data:default
```

Visit `http://localhost:3000` to access your development instance.

**Default credentials:**
- Email: `user@finkey.local`
- Password: `password`

### Development Guides

- [Mac dev setup guide](https://github.com/[your-username]/finkey/wiki/Mac-Dev-Setup-Guide)
- [Linux dev setup guide](https://github.com/[your-username]/finkey/wiki/Linux-Dev-Setup-Guide)
- [Windows dev setup guide](https://github.com/[your-username]/finkey/wiki/Windows-Dev-Setup-Guide)
- Dev containers - visit [this guide](https://code.visualstudio.com/docs/devcontainers/containers) to learn more

## 🏗️ Core Features

### Financial Account Management
- **Bank Accounts**: Checking, savings, credit cards, loans
- **Investments**: Stocks, bonds, ETFs, crypto tracking
- **Real Estate**: Property valuations and mortgage tracking
- **Multi-Currency**: Global currency support with real-time rates

### Advanced Integrations
- **Plaid Integration**: Connect 10,000+ financial institutions
- **Yahoo Finance**: Real-time exchange rates and market data
- **AI Assistant**: Use OpenAI or your own local LLM with full UI configuration - no environment file editing required!
- **Import/Export**: CSV import with intelligent mapping

### Enhanced Features (FinKey Exclusive)
- **UI-Based AI Configuration**: Set up OpenAI or local LLMs through the web interface
- **Expense Reimbursement**: Complex transaction handling
- **Advanced Forecasting**: 24-month projections with trend analysis
- **Improved Docker**: Enhanced deployment and scaling
- **Performance Optimizations**: Faster data processing and UI

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details on:
- Setting up your development environment
- Code style and conventions
- Submitting pull requests
- Reporting issues

## ⚖️ License & Legal

**FinKey** is distributed under the [AGPLv3 license](LICENSE).

### Attribution

This project is a fork of Maybe Finance (https://github.com/maybe-finance/maybe) and includes significant enhancements:
- Original Maybe Finance codebase (AGPLv3)
- Yahoo Finance integration for real-time data
- OpenAI integration for financial insights
- Advanced expense reimbursement system
- Enhanced Docker deployment setup

**Legal Notice**: This fork is **not affiliated with or endorsed by** Maybe Finance Inc. "Maybe" is a trademark of Maybe Finance Inc. All trademark references have been replaced with "FinKey" branding in compliance with AGPLv3 licensing terms.

## 🚀 Deploy Your Own

Ready to take control of your financial data? Deploy FinKey on your own infrastructure:

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.app/new)

Or follow our [self-hosting guide](docs/hosting/docker.md) for other platforms.
