# Yahoo Finance Integration for Maybe Finance

This document describes the Yahoo Finance integration implemented to replace the discontinued Synth API for security price updates.

## Overview

The implementation adds an unofficial price update method using the `yfinance` Python library as an alternative to the Synth API. Users can toggle between official (Synth) and unofficial (Yahoo Finance) price updates through a setting in the self-hosting configuration.

## Implementation Details

### 1. Docker Environment Setup

**Files Modified:**
- `Dockerfile`

**Changes:**
- Added Python 3 and pip to the base Docker image
- Installed yfinance, pandas, and requests Python packages
- Ensures the Docker container has the necessary Python environment for yfinance

### 2. Yahoo Finance Service

**Files Created:**
- `app/services/yahoo_finance_service.rb`

**Features:**
- Ruby service that interfaces with Python yfinance library
- Executes Python scripts safely using temporary files
- Handles price fetching, historical data, and security information
- Supports international markets with proper symbol conversion
- Robust error handling and JSON parsing

### 3. Yahoo Finance Provider

**Files Created:**
- `app/models/provider/yahoo_finance.rb`

**Features:**
- Implements the `SecurityConcept` interface for consistency
- Maps exchange MIC codes to Yahoo Finance symbol suffixes
- Handles various international exchanges (London, Amsterdam, Paris, Frankfurt, etc.)
- Provides proper error handling and logging
- Returns data in the same format as other providers

### 4. Settings Integration

**Files Modified:**
- `app/models/setting.rb`
- `app/controllers/settings/hostings_controller.rb`
- `app/views/settings/hostings/_synth_settings.html.erb`

**Features:**
- Added `use_unofficial_price_updates` boolean setting
- Controller handles the new setting parameter
- UI toggle switch with warning about unofficial data source
- Visual warning styling to alert users about the unofficial nature

### 5. Provider Registry Updates

**Files Modified:**
- `app/models/provider/registry.rb`
- `app/models/security/provided.rb`

**Features:**
- Added Yahoo Finance to the provider registry
- Provider selection based on user setting (Yahoo Finance first when enabled)
- Automatic fallback logic if primary provider fails
- Graceful error handling with fallback to secondary providers

### 6. Testing

**Files Created:**
- `test/models/provider/yahoo_finance_test.rb`
- `test/services/yahoo_finance_service_test.rb`

**Features:**
- Comprehensive test coverage for both service and provider
- Mock-based testing to avoid network calls during tests
- Tests for symbol conversion, error handling, and data parsing
- Validates proper integration with existing interfaces

## Usage

### Enabling Yahoo Finance Updates

⚠️ **CRITICAL FIRST STEP**: The `compose.yml` file has been updated to build from the local Dockerfile instead of pulling from the remote GitHub registry. This ensures your Python/yfinance modifications are included in the container.

1. **Build Updated Container with Local Changes**: 
   ```bash
   docker-compose build --no-cache
   docker-compose up -d
   ```
2. **Access Settings**: Navigate to Settings → Self Hosting in the Maybe app
3. **Enable Toggle**: Toggle on "Use Unofficial price update method"
4. **Verify**: The system will now use Yahoo Finance for price updates instead of Synth API

### Symbol Support

The implementation supports various international exchanges:

- **US Markets**: AAPL, GOOGL, etc.
- **London (XLON)**: VOD.L, BP.L, etc.
- **Amsterdam (XAMS)**: ASML.AS, RDSA.AS, etc.
- **Paris (XPAR)**: LVMH.PA, SAN.PA, etc.
- **Frankfurt (XETR)**: SAP.DE, DAI.DE, etc.
- **Swiss (XSWX)**: NESN.SW, NOVN.SW, etc.
- **Milan (XMIL)**: ISP.MI, ENI.MI, etc.
- **Madrid (XMAD)**: SAN.MC, IBE.MC, etc.
- **Toronto (XTSE)**: SHOP.TO, CNR.TO, etc.
- **Australia (XASX)**: BHP.AX, CBA.AX, etc.
- **Hong Kong (XHKG)**: 0700.HK, 0005.HK, etc.
- **Tokyo (XTKS)**: 7203.T, 6758.T, etc.

## Technical Architecture

### Data Flow

1. **Price Request** → `Security::Provided.import_provider_prices`
2. **Provider Selection** → Registry chooses Yahoo Finance or Synth based on setting
3. **Service Call** → `YahooFinanceService` executes Python yfinance script
4. **Data Processing** → Parse JSON response and convert to domain objects
5. **Fallback Logic** → Try alternative providers if primary fails
6. **Database Storage** → Store prices using existing `Security::Price::Importer`

### Error Handling

- **Network Errors**: Retry logic and fallback to alternative providers
- **Data Parsing Errors**: Graceful error handling with logging
- **Service Unavailable**: Automatic fallback to Synth API if configured
- **Symbol Not Found**: Attempts multiple symbol variations

### Security Considerations

- **Temporary Files**: Python scripts executed via temporary files (no command injection)
- **Input Validation**: All inputs sanitized before Python execution
- **Error Logging**: Detailed error logging for debugging without exposing sensitive data
- **Rate Limiting**: Respects Yahoo Finance's informal rate limits

## Configuration

### Environment Variables

No additional environment variables are required. The system automatically detects Python availability and falls back gracefully if unavailable.

### Settings

- `Setting.use_unofficial_price_updates` - Boolean flag to enable Yahoo Finance
- Persisted in database, configurable through admin UI
- Default: `false` (uses official Synth API when available)

## Monitoring and Logging

### Log Messages

- Provider selection and fallback attempts
- Python script execution results
- Network errors and retry attempts
- Data quality warnings and validation errors

### Sentry Integration

- Error tracking for provider failures
- Context-aware error reporting with security and provider information
- Warning-level alerts for data quality issues

## Limitations and Warnings

### Data Source Disclaimer

Yahoo Finance is an **unofficial** data source and should be used with the understanding that:

1. **No SLA**: No guaranteed uptime or data accuracy
2. **Rate Limits**: Informal rate limits may apply
3. **Data Delays**: May have delays compared to official sources
4. **API Changes**: Yahoo may change or discontinue the service
5. **Legal Compliance**: Users should verify compliance with their usage requirements

### Recommended Usage

- **Development**: Perfect for development and testing environments
- **Personal Use**: Suitable for personal finance tracking
- **Production**: Consider official alternatives for production/commercial use

## Troubleshooting

### Common Issues

1. **Python Not Found**: Ensure Docker rebuild after adding Python dependencies
2. **Network Errors**: Check internet connectivity and firewall settings
3. **Symbol Not Found**: Verify symbol format and exchange suffix
4. **Data Quality**: Monitor logs for parsing errors or invalid data

### Debug Commands

```bash
# Test Python availability
python3 -c "import yfinance; print('OK')"

# Test specific symbol
python3 -c "import yfinance as yf; print(yf.Ticker('AAPL').info['currentPrice'])"

# Check logs
docker logs maybe_web_1 | grep -i yahoo
```

## Future Enhancements

Potential improvements for future versions:

1. **Caching**: Add Redis caching for frequently requested symbols
2. **Batch Processing**: Optimize for bulk price requests
3. **Symbol Discovery**: Enhanced symbol search and validation
4. **Data Validation**: Cross-validation with multiple sources
5. **Performance Monitoring**: Track response times and success rates

## Migration from Synth API

The implementation provides seamless migration:

1. **Existing Data**: All existing Synth data remains intact
2. **Gradual Migration**: Users can switch back and forth between providers
3. **Fallback Support**: Automatic fallback to Synth if Yahoo Finance fails
4. **No Data Loss**: Failed requests don't affect existing historical data

This implementation ensures Maybe Finance users have a reliable alternative for security price updates while maintaining the app's high standards for data quality and user experience.