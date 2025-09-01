# Contributing to Community-Enhanced Personal Finance App

Thank you for considering contributing to this community-maintained fork! This guide will help you get started with contributing to the enhanced features and improvements.

## Community Guidelines

- **Be Respectful**: This is a community project - be kind and constructive
- **Project Conventions**: Read [CLAUDE.md](CLAUDE.md) for development guidelines and Rails conventions
- **Check Existing Work**: Search issues and PRs before starting new work
- **Focus on Features**: Contributions should enhance the three main features: Yahoo Finance, Forecasting, or Expense Reimbursement
- **Quality Over Speed**: We prioritize well-tested, maintainable code
- **Attribution**: Remember this is a fork of Maybe Finance's work - respect their original contributions

## What should I contribute?

This community fork focuses on enhancing and maintaining three core areas:

### 🔄 Yahoo Finance Integration
- **Bug Fixes**: Improve error handling, add more exchanges
- **Performance**: Optimize price update batching
- **Features**: Support for more security types, better symbol validation

### 📊 Enhanced Forecasting
- **Configurability**: Allow users to choose forecast windows (12/18/24/36 months)
- **Accuracy**: Improve seasonal pattern recognition
- **Visualization**: Better forecast charts and explanations

### 💰 Expense Reimbursement
- **Matching**: Link specific expenses to reimbursements
- **Reporting**: Dedicated reimbursement reports
- **Workflow**: Approval workflows, integration with expense tools

### 🛠️ General Improvements
- **Documentation**: User guides, troubleshooting, setup instructions
- **Testing**: Expand test coverage for enhanced features
- **Performance**: Database optimization, query improvements
- **Security**: Security enhancements, vulnerability fixes

For ideas, check [FEATURES.md](FEATURES.md) for current features and potential improvements.

## Development

### Setup

The enhanced version requires Docker for the Python dependencies (Yahoo Finance integration):

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/[your-username]/[fork-name].git
   cd [fork-name]
   ```

2. **Docker Setup** (Recommended):
   ```bash
   cp .env.local.example .env.local
   docker-compose build --no-cache
   docker-compose up -d
   docker-compose exec web bin/setup
   ```

3. **Load Demo Data**:
   ```bash
   docker-compose exec web rake demo_data:default
   ```

4. **Verify Setup**:
   - Visit http://localhost:3000
   - Login: `user@maybe.local` / `password`
   - Test Yahoo Finance: Settings → Hosting → "Update All Prices Now"

See [Development Setup](README.md#local-development-setup) for detailed instructions.

### Making a Pull Request

**Before submitting, ensure all checks pass**:
```bash
# Run tests
docker-compose exec web bin/rails test

# Run linting
docker-compose exec web bin/rubocop -a
docker-compose exec web bundle exec erb_lint ./app/**/*.erb -a

# Security scan
docker-compose exec web bin/brakeman --no-pager
```

**PR Process**:
1. Fork the repo and create feature branch
2. Make focused changes with good commit messages  
3. Add/update tests for your changes
4. Update documentation if needed
5. Ensure all checks pass
6. Create PR with clear description
7. Link to relevant issues
8. Allow maintainer edits
9. Address review feedback

**PR Description Template**:
```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature  
- [ ] Breaking change
- [ ] Documentation update

## Enhanced Features
- [ ] Yahoo Finance improvements
- [ ] Forecasting enhancements
- [ ] Expense reimbursement updates

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] All checks pass

## Documentation
- [ ] User guides updated
- [ ] API docs updated (if applicable)
- [ ] FEATURES.md updated (if significant)
```

All PRs should target the `main` branch.

## ⚖️ License

By contributing, you agree your contributions will be licensed under the [AGPLv3 License](LICENSE).

**Attribution**: This is a community-maintained fork based on Maybe Finance but **NOT affiliated with or endorsed by Maybe Finance Inc.**
