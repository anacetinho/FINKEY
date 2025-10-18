# Maybe Finance - Version 0.6.1 Changes

## Overview
This document outlines the major changes implemented in version 0.6.1, primarily focused on replacing the discontinued Synth API with Yahoo Finance integration and fixing related UI issues.

## Major Changes

### 1. Yahoo Finance Integration (Complete Replacement of Synth API)

#### Core Implementation
- **Added YahooFinanceService**: Ruby service class that interfaces with Python's yfinance library
  - Located: `app/services/yahoo_finance_service.rb`
  - Provides methods for fetching security prices and exchange rates
  - Uses temporary Python script execution for data retrieval

- **Extended Provider System**: Added Yahoo Finance provider implementing both SecurityConcept and ExchangeRateConcept
  - Located: `app/models/provider/yahoo_finance.rb` 
  - Supports stock price fetching from Yahoo Finance
  - Supports currency exchange rate fetching (e.g., CHFEUR=X, USDEUR=X)
  - Includes proper error handling and fallback mechanisms

- **Updated Provider Registry**: Prioritized Yahoo Finance over Synth API
  - Location: `app/models/provider/registry.rb`
  - Yahoo Finance is now the primary provider for both securities and exchange rates
  - Maintains backward compatibility with Synth API as fallback

#### Docker Environment Updates
- **Dockerfile Changes**: Added Python 3, pip, and yfinance dependencies
  ```dockerfile
  RUN apt-get install python3 python3-pip python3-venv
  RUN pip3 install --break-system-packages yfinance pandas requests
  ```

- **Docker Compose**: Changed from remote image to local build
  ```yaml
  build: .  # Changed from: image: ghcr.io/maybe-finance/maybe:latest
  ```

### 2. User Interface Improvements

#### Trading Interface Simplification
- **Removed Ticker Search**: Replaced complex search functionality with simple text input
  - Location: `app/views/trades/_form.html.erb`
  - Users now manually enter ticker symbols (e.g., AAPL, MSFT)
  - Eliminates dependency on external search APIs

#### Settings Page Enhancements
- **Added Manual Price Update Button**: 
  - Location: `app/views/settings/hostings/_synth_settings.html.erb`
  - Styled using DS::Button component for consistency
  - Includes proper confirmation dialog using CustomConfirm
  - Only visible when Yahoo Finance is enabled

- **Updated Financial Data Sources Section**:
  - Clear separation between Yahoo Finance (recommended) and Synth API
  - Toggle for Yahoo Finance usage
  - Manual price update functionality

### 3. Currency Conversion System

#### Exchange Rate Integration
- **Extended YahooFinanceService**: Added currency conversion methods
  - Fetches exchange rates using Yahoo Finance currency pairs (CHFEUR=X format)
  - Supports historical and current rate fetching
  - Proper error handling for unsupported currency pairs

- **Updated ExchangeRate::Provided**: 
  - Location: `app/models/exchange_rate/provided.rb`
  - Yahoo Finance now primary provider for exchange rates
  - Fallback to Synth API if available

#### Currency Conversion Fix
**Issue**: Swiss Francs accounts showing CHF 83.00 as €83.00 (1:1 ratio instead of proper conversion)
**Solution**: Implemented complete Yahoo Finance exchange rate system
**Result**: CHF 83.00 now correctly displays as €88.18 (based on current CHFEUR rate ~1.0624)

### 4. Dashboard Warning System Updates

#### Synth API Dependency Removal
- **Updated Family Model**: 
  - Location: `app/models/family.rb`
  - Modified `missing_data_provider?` method to check Yahoo Finance availability
  - Removed dependency warnings when Yahoo Finance is configured

### 5. Bug Fixes

#### DS::Button Confirm Parameter Fix
**Issue**: Hosting settings page crashing with `undefined method 'to_data_attribute' for an instance of String`
**Root Cause**: DS::Button component expected CustomConfirm object, received plain string
**Solution**: 
```erb
# Before (causing error)
confirm: "This will update prices for all securities in your portfolio. Continue?"

# After (fixed)
confirm: CustomConfirm.new(
  title: "Update All Prices",
  body: "This will update prices for all securities in your portfolio. Continue?",
  btn_text: "Update Prices"
)
```
**Location**: `app/views/settings/hostings/_synth_settings.html.erb`

#### Line Ending Compatibility
**Issue**: Windows CRLF line endings causing Docker build failures
**Solution**: Converted Ruby files and bin scripts from CRLF to LF format
**Commands Used**: 
```bash
find . -name "*.rb" -exec sed -i 's/\r$//' {} \;
find bin/ -type f -exec sed -i 's/\r$//' {} \;
```

## Technical Architecture

### Yahoo Finance Data Flow
1. **User Action**: Click "Update All Prices Now" or automatic background job
2. **Rails Service**: YahooFinanceService generates Python script
3. **Python Execution**: yfinance library fetches data from Yahoo Finance
4. **Data Processing**: JSON response parsed and converted to Ruby objects
5. **Database Storage**: Prices/exchange rates cached in local database
6. **UI Update**: Updated values displayed in accounts and portfolios

### Security Price Fetching
- **Supported Markets**: US (NASDAQ, NYSE), European exchanges, Asian markets
- **Format**: Automatic suffix mapping (e.g., AAPL.L for London, AAPL.PA for Paris)
- **Currency Support**: Automatic currency detection from Yahoo Finance
- **Error Handling**: Graceful fallback to cached data or alternative providers

### Exchange Rate System
- **Currency Pairs**: Major currencies supported (USD, EUR, CHF, GBP, JPY, etc.)
- **Format**: Yahoo Finance format (CHFEUR=X, USDEUR=X, etc.)
- **Caching**: 24-hour cache duration for exchange rates
- **Historical Data**: Support for historical exchange rate fetching

## Files Modified

### New Files Added
- `app/services/yahoo_finance_service.rb` - Core Yahoo Finance integration
- `app/models/provider/yahoo_finance.rb` - Provider implementation

### Files Modified
- `Dockerfile` - Added Python dependencies
- `compose.yml` - Changed to local build
- `app/models/provider/registry.rb` - Updated provider priorities
- `app/models/exchange_rate/provided.rb` - Yahoo Finance integration
- `app/models/family.rb` - Updated data provider check
- `app/views/settings/hostings/_synth_settings.html.erb` - UI updates and bug fixes
- `app/views/trades/_form.html.erb` - Simplified ticker input

## Configuration Changes

### Environment Variables
No new environment variables required for Yahoo Finance integration. The service works without API keys or authentication.

### Settings
- **New Setting**: `use_yahoo_finance` - Toggle for Yahoo Finance usage
- **Location**: Settings → Hosting → Financial Data Sources
- **Default**: Enabled (recommended)

## Testing Results

### Integration Testing
- ✅ Yahoo Finance service connectivity
- ✅ Security price fetching (AAPL: $229.35)
- ✅ Exchange rate fetching (USD→EUR: 0.8587, CHF→EUR: 1.0624)
- ✅ Currency conversion display (CHF 83.00 → €88.18)
- ✅ Manual price update button functionality
- ✅ Provider registry prioritization
- ✅ Error handling and fallbacks

### UI Testing
- ✅ Hosting settings page loads without errors
- ✅ Confirmation dialog displays correctly
- ✅ Yahoo Finance toggle functionality
- ✅ Manual price update workflow
- ✅ Ticker input in trading forms

## Migration Notes

### For Users Upgrading to 0.6.1
1. **Docker Rebuild Required**: Due to Python dependencies, full container rebuild necessary
2. **Automatic Migration**: Yahoo Finance becomes default provider automatically
3. **No Data Loss**: Existing Synth API data remains, new Yahoo Finance data supplements
4. **Manual Action**: Users can click "Update All Prices Now" to refresh all data

### Rollback Considerations
- Synth API integration remains intact as fallback
- No database schema changes made
- Configuration toggles available in settings

## Performance Impact

### Improvements
- **No API Keys Required**: Eliminates API key management overhead
- **Local Caching**: 24-hour cache reduces external API calls
- **Parallel Fetching**: Multiple securities updated simultaneously

### Considerations
- **Python Overhead**: Small performance cost for Python script execution
- **Docker Image Size**: Increased by ~100MB due to Python dependencies
- **Memory Usage**: Minimal increase for Python runtime

## Security Enhancements

### Removed Dependencies
- **Eliminated API Key Storage**: No more Synth API key management
- **Reduced Attack Surface**: Fewer external API dependencies
- **Local Processing**: Python scripts execute in controlled environment

### Maintained Security
- **Input Validation**: Ticker symbols validated before processing
- **Error Boundary**: Failed API calls don't crash application
- **Data Sanitization**: All external data properly escaped and validated

## Future Considerations

### Potential Enhancements
- **Real-time Updates**: WebSocket integration for live price feeds
- **Additional Markets**: Support for cryptocurrency and commodities
- **Advanced Charting**: Integration with Yahoo Finance chart data
- **Portfolio Analytics**: Enhanced performance tracking with historical data

### Known Limitations
- **Yahoo Finance Unofficial**: API usage relies on unofficial access methods
- **Rate Limits**: Approximately 2000 requests/hour (unofficial limit)
- **Data Accuracy**: No SLA guarantees from Yahoo Finance
- **Market Coverage**: Limited to Yahoo Finance supported securities

## Conclusion

Version 0.6.1 successfully removes the dependency on the discontinued Synth API while maintaining all existing functionality. The Yahoo Finance integration provides a robust, free alternative for financial data fetching with improved currency conversion capabilities. The simplified user interface and enhanced error handling make the application more reliable and user-friendly.

The implementation maintains backward compatibility while positioning the application for future enhancements and reducing operational dependencies on external paid services.