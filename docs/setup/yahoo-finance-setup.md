# Yahoo Finance Setup Guide

This guide walks you through setting up and configuring the Yahoo Finance integration for security price updates.

## Prerequisites

- Docker and Docker Compose installed
- Access to administrator settings in the application

## Installation Steps

### 1. Build the Enhanced Container

The Yahoo Finance integration requires Python and additional libraries. Build the container with these dependencies:

```bash
# Stop existing containers
docker-compose down

# Build with no cache to ensure all dependencies are installed
docker-compose build --no-cache

# Start the application
docker-compose up -d
```

### 2. Verify Python Dependencies

The Docker build automatically installs:
- Python 3
- pip (Python package installer)  
- yfinance library
- pandas (data manipulation)
- requests (HTTP library)

You can verify the installation by checking the container logs:
```bash
docker-compose logs web | grep -i python
```

### 3. Enable Yahoo Finance in Settings

1. **Access Admin Settings**:
   - Log in to your application
   - Navigate to **Settings** → **Hosting**

2. **Enable Yahoo Finance**:
   - Find the "Yahoo Finance Integration" section
   - Check the box for "Use Yahoo Finance for price updates"
   - Click "Save Settings"

3. **Test the Integration**:
   - Click the "Update All Prices Now" button
   - Monitor the process for any error messages
   - Check that prices are updated for your securities

## Configuration Options

### Provider Priority

The application uses this priority order for security price updates:
1. **Yahoo Finance** (when enabled)
2. **Synth API** (if available and configured)
3. **Manual entry** (fallback)

### Update Frequency

- **Manual Updates**: Administrators control when prices are updated
- **On-Demand**: Click "Update All Prices Now" in settings
- **No Automatic Updates**: Prevents conflicts and rate limiting issues

### Supported Symbol Formats

The Yahoo Finance integration automatically handles symbol formatting for different exchanges:

**US Markets** (no suffix needed):
```
AAPL, GOOGL, TSLA, MSFT, NVDA
```

**International Markets** (automatic suffix mapping):
```
London Stock Exchange: BP.L, VOD.L, LLOY.L
Amsterdam: ASML.AS, RDSA.AS  
Paris: LVMH.PA, SAN.PA
Frankfurt: SAP.DE, DAI.DE
Swiss: NESN.SW, NOVN.SW
```

## Adding Securities and Trades

### 1. Simple Ticker Entry

When adding trades in investment accounts:

1. **Go to Investment Account**: Click on your investment account
2. **Add Trade**: Click "Add Trade" button
3. **Enter Ticker**: Type the ticker symbol directly (e.g., "AAPL")
4. **No Search Required**: Proceed immediately without waiting
5. **Complete Trade**: Fill in quantity, price, and date information

### 2. International Securities

For international stocks, use the standard ticker format:
- **London**: `BP.L` (not just "BP")
- **Amsterdam**: `ASML.AS` (not just "ASML")
- **Paris**: `LVMH.PA` (not just "LVMH")

The system will automatically format these for Yahoo Finance.

### 3. Price Updates

After adding securities:
1. Go to **Settings** → **Hosting**
2. Click "Update All Prices Now"
3. Check holdings page for updated prices

## Troubleshooting

### Common Issues

#### 1. Python Not Found Error
**Symptom**: Error messages about Python not being available
**Solution**: 
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

#### 2. yfinance Module Not Found
**Symptom**: "No module named 'yfinance'" error
**Solution**: Rebuild container to install Python dependencies
```bash
docker-compose build --no-cache web
```

#### 3. Network Timeout Errors
**Symptom**: Price updates fail with timeout messages
**Solution**: 
- Check internet connection
- Try updating smaller batches of securities
- Wait a few minutes and retry

#### 4. Invalid Symbol Errors
**Symptom**: Specific symbols fail to update
**Solution**:
- Verify ticker symbol spelling
- Check if security is traded on supported exchanges
- Try updating other securities to isolate the issue

### Debug Mode

To enable detailed logging for troubleshooting:

1. **Check Container Logs**:
   ```bash
   docker-compose logs web | grep -i yahoo
   ```

2. **Rails Console Debug**:
   ```bash
   docker-compose exec web rails console
   # In console:
   YahooFinanceService.new.get_current_price("AAPL")
   ```

### Getting Help

If you encounter issues:

1. **Check Logs**: Always check Docker logs first
2. **Verify Setup**: Ensure Python dependencies are installed
3. **Test Simple Case**: Try with a US stock like "AAPL"
4. **Check Network**: Verify internet connectivity from container

### Performance Optimization

For best performance:

- **Update During Off-Hours**: Run updates when markets are closed
- **Batch Updates**: Update all securities at once rather than individually
- **Monitor Resources**: Watch CPU/memory usage during large updates

## Advanced Configuration

### Custom Python Scripts

The Yahoo Finance service can be extended with custom Python scripts. Scripts are executed in a secure temporary environment with JSON-only output.

### Exchange Rate Integration

Yahoo Finance integration works alongside the existing exchange rate system for multi-currency support.

### Provider Fallback

If Yahoo Finance fails, the system automatically falls back to other configured providers (like Synth API) without user intervention.

## Next Steps

Once Yahoo Finance is configured:

1. **Add Investment Accounts**: Set up your brokerage accounts
2. **Enter Trades**: Add your security transactions using simple ticker symbols
3. **Regular Updates**: Establish a routine for updating prices (daily/weekly)
4. **Monitor Performance**: Use the enhanced forecasting to track portfolio performance

For more detailed information about investment tracking, see the [Investment Account Guide](../features/yahoo-finance.md).