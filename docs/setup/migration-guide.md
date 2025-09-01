# Migration Guide from Original Maybe

This guide helps you migrate from the original Maybe Finance app to this enhanced community fork.

## Overview

This community fork maintains full compatibility with the original Maybe database structure while adding new features. Your existing data will be preserved during migration.

## Pre-Migration Checklist

### 1. Backup Your Data

**Critical**: Always backup your data before migration.

```bash
# Export your data using the original Maybe app
# Go to Settings → Export → Create Full Export
# Download and save the export file securely

# For Docker users, backup the database volume
docker-compose exec db pg_dump -U maybe_user maybe_production > backup.sql
```

### 2. Note Your Current Configuration

Document your current setup:
- Environment variables in `.env` files
- Custom configuration in `compose.yml` 
- Any manual database modifications
- Third-party integrations (Plaid, etc.)

### 3. Test Environment

Set up a test environment first:
```bash
# Clone your production data to test
cp -r /path/to/production /path/to/test
cd /path/to/test
# Test migration process
```

## Migration Steps

### Option 1: In-Place Upgrade (Recommended)

This approach upgrades your existing installation while preserving all data.

#### 1. Stop Current Application
```bash
cd /path/to/your/maybe/app
docker-compose down
```

#### 2. Backup Current Installation
```bash
# Create backup directory
mkdir ../maybe-backup-$(date +%Y%m%d)

# Copy entire installation
cp -r . ../maybe-backup-$(date +%Y%m%d)/

# Backup database
docker-compose exec db pg_dump -U maybe_user maybe_production > ../maybe-backup-$(date +%Y%m%d)/database.sql
```

#### 3. Update to Enhanced Fork
```bash
# Add the enhanced fork as a remote (if using Git)
git remote add enhanced-fork https://github.com/[your-username]/[your-fork-name].git
git fetch enhanced-fork

# OR download and extract the enhanced version
wget https://github.com/[your-username]/[your-fork-name]/archive/main.zip
unzip main.zip
```

#### 4. Merge Configuration
```bash
# Copy your environment configuration
cp ../maybe-backup-$(date +%Y%m%d)/.env.local .env.local

# Update compose.yml if needed (the enhanced version includes Python dependencies)
# Compare your old compose.yml with the new one and merge settings
```

#### 5. Build and Start Enhanced Version
```bash
# Build with enhanced dependencies
docker-compose build --no-cache

# Start the application
docker-compose up -d

# Check logs for any issues
docker-compose logs web
```

#### 6. Run Database Migrations
```bash
# The enhanced version includes new database migrations
docker-compose exec web rails db:migrate

# Check migration status
docker-compose exec web rails db:migrate:status
```

#### 7. Verify Data Integrity
```bash
# Check that your accounts and transactions are intact
docker-compose exec web rails console

# In Rails console:
puts "Users: #{User.count}"
puts "Accounts: #{Account.count}"  
puts "Transactions: #{Transaction.count}"
puts "Categories: #{Category.count}"
```

### Option 2: Side-by-Side Migration

This approach sets up the enhanced version alongside your current installation.

#### 1. Set Up Enhanced Version
```bash
# Clone enhanced fork to new directory
git clone https://github.com/[your-username]/[your-fork-name].git maybe-enhanced
cd maybe-enhanced
```

#### 2. Configure New Installation
```bash
# Copy configuration from original
cp ../maybe-original/.env.local .env.local

# Update database connection to use different database
# Edit .env.local to change DATABASE_URL to use different database name
```

#### 3. Import Data
```bash
# Create database dump from original
cd ../maybe-original
docker-compose exec db pg_dump -U maybe_user maybe_production > data-export.sql

# Import to new installation
cd ../maybe-enhanced
docker-compose up -d db
docker-compose exec db psql -U maybe_user -d maybe_enhanced_production < ../maybe-original/data-export.sql
```

#### 4. Start Enhanced Application
```bash
docker-compose build --no-cache
docker-compose up -d
```

## Post-Migration Steps

### 1. Verify Enhanced Features

#### Yahoo Finance Integration
1. Go to **Settings** → **Hosting**
2. Enable "Use Yahoo Finance for price updates"
3. Test with "Update All Prices Now" button
4. Check that security prices update correctly

#### Enhanced Forecasting
1. Check that forecasts on dashboard reflect recent financial changes
2. Compare forecast values before and after migration
3. Verify that 24-month window is active (forecasts should be more responsive)

#### Expense Reimbursement
1. Create a test category with "Allow negative expenses" enabled
2. Add a test expense and reimbursement transaction
3. Verify net worth and budget calculations are correct

### 2. Update Workflows

#### Investment Tracking
- **Old Way**: Complex ticker search with delays
- **New Way**: Direct ticker entry (e.g., type "AAPL" and proceed)

#### Price Updates
- **Old Way**: Automatic background updates (if Synth API was configured)
- **New Way**: Manual updates via Settings → Hosting → "Update All Prices Now"

#### Forecasting
- **Old Way**: All historical data used for calculations
- **New Way**: 24-month rolling window for more responsive forecasts

### 3. Clean Up Old Installation

Only after confirming the migration was successful:

```bash
# Stop old installation
cd /path/to/original/maybe
docker-compose down

# Archive old installation
mv /path/to/original/maybe /path/to/archived/maybe-original-$(date +%Y%m%d)
```

## Troubleshooting Migration Issues

### Database Migration Failures

**Symptoms**: Migrations fail during startup

**Solutions**:
```bash
# Check migration status
docker-compose exec web rails db:migrate:status

# Run migrations manually
docker-compose exec web rails db:migrate

# If migrations are stuck, check for conflicting schema changes
docker-compose exec web rails console
ActiveRecord::Base.connection.execute("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 10;")
```

### Missing Environment Variables

**Symptoms**: Application fails to start, missing configuration errors

**Solutions**:
```bash
# Compare environment files
diff ../maybe-original/.env.local .env.local

# Check for new required variables in the enhanced version
grep -r "ENV\[" app/ | grep -v test
```

### Python/Yahoo Finance Issues

**Symptoms**: Price updates fail, Python-related errors

**Solutions**:
```bash
# Verify Python installation in container
docker-compose exec web python3 --version

# Rebuild container if Python dependencies missing
docker-compose build --no-cache web
```

### Data Inconsistencies

**Symptoms**: Missing transactions, incorrect balances

**Solutions**:
```bash
# Run data integrity checks
docker-compose exec web rails console

# In Rails console, check for data consistency:
Account.all.each { |a| puts "#{a.name}: #{a.entries.count} entries" }
```

## Rollback Procedure

If migration fails and you need to rollback:

### 1. Stop Enhanced Version
```bash
cd /path/to/enhanced/maybe
docker-compose down
```

### 2. Restore Original Version
```bash
# Restore from backup
cp -r /path/to/maybe-backup-[date]/* /path/to/original/maybe/
cd /path/to/original/maybe

# Restore database if needed
docker-compose up -d db
docker-compose exec db psql -U maybe_user -d maybe_production < database.sql

# Start original version
docker-compose up -d
```

### 3. Verify Rollback
```bash
# Check that original application works correctly
docker-compose logs web
```

## Support and Help

If you encounter issues during migration:

1. **Check Logs**: Always examine Docker logs first
   ```bash
   docker-compose logs web
   docker-compose logs db
   ```

2. **Database Status**: Verify database connectivity and migrations
   ```bash
   docker-compose exec web rails db:migrate:status
   ```

3. **Configuration**: Compare your configuration with working examples

4. **Community Support**: Ask for help in the project's GitHub discussions or issues

## Next Steps

After successful migration:

1. **Explore New Features**: Try the Yahoo Finance integration and enhanced forecasting
2. **Update Documentation**: Update any personal documentation about your setup
3. **Set Up Monitoring**: Consider setting up monitoring for your enhanced installation
4. **Regular Backups**: Implement regular backup procedures for your enhanced setup

Remember that this is a community-maintained fork. While we strive for stability, always maintain regular backups of your financial data.