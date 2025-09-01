# Yahoo Finance Integration

## Overview

This enhanced personal finance app includes Yahoo Finance integration to replace the discontinued Synth API for real-time security price updates. This integration provides reliable price data for US and international securities.

## Key Features

- **Real-time Price Updates**: Get current prices from Yahoo Finance
- **International Exchange Support**: Supports US, European, and Asian markets
- **Simple Ticker Entry**: Direct ticker symbol input instead of complex search
- **Manual Price Control**: Admin-controlled price updates through settings
- **Fallback Support**: Falls back to other providers if Yahoo Finance fails

## Supported Markets

### US Markets
- **Symbols**: AAPL, GOOGL, TSLA, MSFT, etc.
- **Exchange**: NASDAQ, NYSE

### International Markets
- **London (XLON)**: VOD.L, BP.L, LLOY.L
- **Amsterdam (XAMS)**: ASML.AS, RDSA.AS
- **Paris (XPAR)**: LVMH.PA, SAN.PA
- **Frankfurt (XETR)**: SAP.DE, DAI.DE
- **Swiss (XSWX)**: NESN.SW, NOVN.SW

## How to Use

### For Users
1. When adding trades, simply type the ticker symbol directly (e.g., "AAPL")
2. No need to wait for search results - proceed immediately
3. Prices will be updated when administrators run manual updates

### For Administrators
1. Go to **Settings** → **Hosting**
2. Ensure "Use Yahoo Finance for price updates" is enabled
3. Click "Update All Prices Now" to fetch latest prices
4. Monitor logs for update status and errors

## Technical Implementation

### Docker Integration
The Yahoo Finance integration requires Python and the yfinance library, which are included in the Docker build:

```dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install yfinance pandas requests
```

### Service Architecture
- **YahooFinanceService**: Ruby service that executes Python scripts safely
- **YahooFinance Provider**: Implements security provider interface
- **Symbol Formatting**: Handles international exchange suffix mapping
- **Error Handling**: Comprehensive exception catching and fallback

### Security Features
- Python scripts executed via temporary files (no command injection)
- Input sanitization before execution
- Output stream redirection prevents JSON corruption
- User access control for update functionality

## Benefits

### Performance Improvements
- **No Search Delays**: Removed 30+ second symbol searches
- **Manual Updates Only**: No background job conflicts
- **Direct Input**: Type ticker and proceed immediately

### Reliability
- **Robust Error Handling**: Comprehensive exception catching
- **Graceful Degradation**: Falls back to existing providers
- **Clean Architecture**: Service layer isolates Python integration

### User Experience
- **Immediate Entry**: No waiting for autocomplete
- **Admin Control**: Administrators decide when to update prices
- **Clear Feedback**: Success/error messages for operations