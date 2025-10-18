class Provider::YahooFinance < Provider
  include SecurityConcept, ExchangeRateConcept

  # Subclass for specific Yahoo Finance errors
  Error = Class.new(Provider::Error)

  def initialize
    @service = YahooFinanceService.new
  end

  def healthy?
    with_provider_response do
      @service.test_connection
    end
  end

  # Implementation of SecurityConcept interface
  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      # For simplicity, we'll just return the symbol as-is since we removed search
      # This matches the user requirement to not have search functionality
      info = @service.fetch_security_info(symbol)
      
      if info
        [
          Security.new(
            symbol: symbol.upcase,
            name: info[:name],
            logo_url: nil, # Yahoo Finance doesn't provide logos via yfinance
            exchange_operating_mic: map_exchange_to_mic(info[:exchange]),
            country_code: country_code || "US"
          )
        ]
      else
        []
      end
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      yahoo_symbol = format_symbol_for_yahoo(symbol, exchange_operating_mic)
      info = @service.fetch_security_info(yahoo_symbol)
      
      return nil unless info

      SecurityInfo.new(
        symbol: symbol,
        name: info[:name],
        links: nil,
        logo_url: nil,
        description: nil,
        kind: "stock", # Default to stock for Yahoo Finance
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      yahoo_symbol = format_symbol_for_yahoo(symbol, exchange_operating_mic)
      price_data = @service.fetch_current_price(yahoo_symbol)
      
      return nil unless price_data

      Price.new(
        symbol: symbol,
        date: date.to_date,
        price: price_data[:price],
        currency: price_data[:currency],
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      yahoo_symbol = format_symbol_for_yahoo(symbol, exchange_operating_mic)
      historical_data = @service.fetch_historical_prices(yahoo_symbol, start_date, end_date)
      
      historical_data.map do |price_data|
        Price.new(
          symbol: symbol,
          date: price_data[:date],
          price: price_data[:price],
          currency: price_data[:currency],
          exchange_operating_mic: exchange_operating_mic
        )
      end
    end
  end

  # Implementation of ExchangeRateConcept interface
  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      rate_data = @service.fetch_exchange_rate(from, to, date)
      
      return nil unless rate_data

      Rate.new(
        date: rate_data[:date],
        from: rate_data[:from],
        to: rate_data[:to],
        rate: rate_data[:rate]
      )
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      historical_data = @service.fetch_exchange_rates(from, to, start_date, end_date)
      
      historical_data.map do |rate_data|
        Rate.new(
          date: rate_data[:date],
          from: rate_data[:from],
          to: rate_data[:to],
          rate: rate_data[:rate]
        )
      end
    end
  end

  private

  def format_symbol_for_yahoo(symbol, exchange_operating_mic)
    return symbol if exchange_operating_mic.blank?

    # Map exchange MIC codes to Yahoo Finance suffixes
    suffix = case exchange_operating_mic.upcase
             when "XLON" then ".L"      # London Stock Exchange
             when "XAMS" then ".AS"     # Euronext Amsterdam
             when "XPAR" then ".PA"     # Euronext Paris
             when "XETR", "XFRA" then ".DE" # XETRA/Frankfurt
             when "XSWX" then ".SW"     # SIX Swiss Exchange
             when "XMIL" then ".MI"     # Borsa Italiana
             when "XMAD" then ".MC"     # Bolsa de Madrid
             when "XTSE" then ".TO"     # Toronto Stock Exchange
             when "XASX" then ".AX"     # Australian Securities Exchange
             when "XHKG" then ".HK"     # Hong Kong Stock Exchange
             when "XTKS" then ".T"      # Tokyo Stock Exchange
             else ""                    # Default to no suffix (US markets)
             end

    "#{symbol}#{suffix}"
  end

  def map_exchange_to_mic(exchange_name)
    return "XNAS" if exchange_name.blank? # Default to NASDAQ

    # Basic mapping from Yahoo exchange names to MIC codes
    case exchange_name.upcase
    when /NYSE/ then "XNYS"
    when /NASDAQ/ then "XNAS"
    when /LSE/, /LONDON/ then "XLON"
    when /AMSTERDAM/ then "XAMS"
    when /PARIS/ then "XPAR"
    when /XETRA/, /FRANKFURT/ then "XETR"
    when /SWISS/ then "XSWX"
    when /MILAN/ then "XMIL"
    when /MADRID/ then "XMAD"
    when /TORONTO/ then "XTSE"
    when /ASX/ then "XASX"
    when /HONG.?KONG/ then "XHKG"
    when /TOKYO/ then "XTKS"
    else "XNAS" # Default fallback
    end
  end

  def default_error_transformer(error)
    Error.new(error.message, details: error.respond_to?(:details) ? error.details : nil)
  end
end