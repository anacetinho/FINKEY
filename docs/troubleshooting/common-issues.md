# Common Issues and Troubleshooting

This guide covers common issues you might encounter with the enhanced personal finance app and their solutions.

## Yahoo Finance Integration Issues

### Python Dependencies Missing

**Symptoms:**
- "Python command not found" errors
- "No module named 'yfinance'" errors
- Price updates fail silently

**Solution:**
```bash
# Rebuild container with Python dependencies
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Verify Python installation
docker-compose exec web python3 --version
docker-compose exec web pip3 list | grep yfinance
```

### Price Update Failures

**Symptoms:**
- "Update All Prices Now" button shows errors
- Some securities update while others fail
- Network timeout messages

**Diagnostic Steps:**
```bash
# Check container logs
docker-compose logs web | grep -i yahoo

# Test specific ticker
docker-compose exec web rails console
YahooFinanceService.new.get_current_price("AAPL")
```

**Solutions:**
1. **Network Issues**: Verify internet connectivity from container
2. **Invalid Tickers**: Double-check ticker symbol spelling and exchange suffixes
3. **Rate Limiting**: Wait 5-10 minutes between large batch updates
4. **Yahoo Finance Down**: Check Yahoo Finance website status

### Docker File Synchronization

**Symptoms:**
- Code changes not reflected in running container
- New features not working despite file modifications

**Solution:**
```bash
# For development: Ensure volume mounts are working
docker-compose down
docker-compose up -d

# For modified code files: Manual copy to container
docker cp ./app/services/yahoo_finance_service.rb container_name:/rails/app/services/
docker-compose restart web
```

## Forecasting Issues

### Sticky Forecasts Not Updating

**Symptoms:**
- Forecasts don't change despite recent transaction changes
- Old patterns still influencing projections

**Diagnostic Steps:**
```bash
# Check if 24-month filtering is active
docker-compose exec web rails console

# In Rails console:
family = Family.first
stats = IncomeStatement::FamilyStats.new(family: family, interval: :month)
puts stats.totals
```

**Solutions:**
1. **Clear Cache**: Clear application cache to recalculate forecasts
2. **Check Date Range**: Verify 24-month window is calculating correctly
3. **Transaction Data**: Ensure recent transactions are properly categorized

### Median Calculation Errors

**Symptoms:**
- Forecast medians show unexpected values
- Database errors in statistics calculations

**Solution:**
```bash
# Check database integrity
docker-compose exec db psql -U maybe_user -d maybe_production

# In PostgreSQL:
SELECT COUNT(*) FROM entries WHERE date >= DATE_TRUNC('month', NOW() - INTERVAL '24 months');
```

## Expense Reimbursement Issues

### Balance Calculations Wrong

**Symptoms:**
- Reimbursements not increasing account balances
- Net worth not reflecting reimbursement benefits

**Diagnostic Steps:**
```bash
# Check entry classification
docker-compose exec web rails console

# In Rails console:
category = Category.find_by(allows_negative_expenses: true)
entries = category.transactions.joins(:entry).map(&:entry)
entries.each { |e| puts "Amount: #{e.amount}, Classification: #{e.classification}" }
```

**Solutions:**
1. **Category Flag**: Ensure category has `allows_negative_expenses = true`
2. **Entry Storage**: Verify positive amounts are stored for reimbursements
3. **Balance Recalculation**: Force recalculation of account balances

### Median Calculation Issues

**Symptoms:**
- Forecasts show separate entries for expenses and reimbursements
- Monthly totals not combining properly

**Solution:**
Check the SQL GROUP BY clause in family_stats.rb and category_stats.rb ensures monthly totals are properly combined.

## Database Issues

### Migration Failures

**Symptoms:**
- Application won't start due to pending migrations
- Database schema version mismatches

**Solution:**
```bash
# Run pending migrations
docker-compose exec web rails db:migrate

# Check migration status
docker-compose exec web rails db:migrate:status

# If migrations are stuck, reset (CAUTION: destroys data)
docker-compose exec web rails db:reset
```

### Connection Issues

**Symptoms:**
- "Could not connect to database" errors
- Application fails to start

**Solution:**
```bash
# Check database container status
docker-compose ps

# Restart database container
docker-compose restart db

# Check database logs
docker-compose logs db

# Verify environment variables
docker-compose exec web env | grep DATABASE
```

## Performance Issues

### Slow Query Performance

**Symptoms:**
- Dashboard loads slowly
- Forecast calculations take too long
- Timeout errors

**Diagnostic Steps:**
```bash
# Monitor query performance
docker-compose logs web | grep "Completed.*ms"

# Check database performance
docker-compose exec db psql -U maybe_user -d maybe_production
\timing on
SELECT COUNT(*) FROM entries WHERE date >= NOW() - INTERVAL '24 months';
```

**Solutions:**
1. **Database Indexes**: Ensure proper indexes exist on date columns
2. **Query Optimization**: Review slow queries and optimize
3. **Data Cleanup**: Archive or remove very old data if not needed

### Memory Issues

**Symptoms:**
- Application crashes with out-of-memory errors
- Container restarts frequently

**Solution:**
```bash
# Increase memory limits in docker-compose.yml
services:
  web:
    deploy:
      resources:
        limits:
          memory: 2G

# Monitor memory usage
docker stats
```

## Docker and Container Issues

### Build Failures

**Symptoms:**
- Docker build fails during dependency installation
- Missing packages in container

**Solution:**
```bash
# Clean Docker cache
docker system prune -a

# Rebuild from scratch
docker-compose build --no-cache --pull

# Check Dockerfile for syntax errors
```

### Volume Mount Issues

**Symptoms:**
- File changes not reflected in container
- Permission denied errors

**Solution:**
```bash
# Fix file permissions (Linux/Mac)
sudo chown -R $USER:$USER .

# Check volume mounts
docker-compose config

# Restart with fresh volumes
docker-compose down -v
docker-compose up -d
```

## Getting Support

### Log Collection

When reporting issues, include:

```bash
# Application logs
docker-compose logs web > application.log

# Database logs  
docker-compose logs db > database.log

# Container status
docker-compose ps > container_status.txt

# System info
docker version > docker_info.txt
docker-compose version >> docker_info.txt
```

### Environment Information

Include this information when reporting issues:
- Operating system and version
- Docker and Docker Compose versions
- Application version/commit hash
- Browser version (if UI-related)
- Steps to reproduce the issue

### Debug Mode

For more detailed logging:

```bash
# Enable Rails debug logging
docker-compose exec web rails console
Rails.logger.level = Logger::DEBUG
```

### Reset Options

If issues persist, consider these reset options:

**Soft Reset** (preserves data):
```bash
docker-compose restart
```

**Medium Reset** (rebuilds containers):
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

**Hard Reset** (destroys all data):
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

**Note**: Hard reset will destroy all your financial data. Only use as a last resort and ensure you have backups.