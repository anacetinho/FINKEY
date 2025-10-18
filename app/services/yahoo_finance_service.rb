class YahooFinanceService
  class Error < StandardError; end

  def initialize
    @python_path = detect_python_path
    raise Error, "Python 3 not found in system" unless @python_path
  end

  def fetch_current_price(symbol)
    script = build_price_script(symbol, Date.current)
    result = execute_python_script(script)
    
    return nil if result.nil?
    
    {
      symbol: symbol,
      price: result["price"],
      currency: result["currency"] || "USD",
      date: Date.current
    }
  end

  def fetch_historical_prices(symbol, start_date, end_date)
    script = build_historical_script(symbol, start_date, end_date)
    result = execute_python_script(script)
    
    return [] if result.nil? || result["prices"].nil?
    
    result["prices"].map do |price_data|
      {
        symbol: symbol,
        date: Date.parse(price_data["date"]),
        price: price_data["price"],
        currency: result["currency"] || "USD"
      }
    end
  end

  def fetch_security_info(symbol)
    script = build_info_script(symbol)
    result = execute_python_script(script)
    
    return nil if result.nil?
    
    {
      symbol: symbol,
      name: result["name"],
      currency: result["currency"] || "USD",
      exchange: result["exchange"]
    }
  end

  def fetch_exchange_rate(from_currency, to_currency, date)
    script = build_exchange_rate_script(from_currency, to_currency, date)
    result = execute_python_script(script)
    
    return nil if result.nil?
    
    {
      from: from_currency,
      to: to_currency,
      rate: result["rate"],
      date: Date.parse(result["date"])
    }
  end

  def fetch_exchange_rates(from_currency, to_currency, start_date, end_date)
    script = build_historical_exchange_rate_script(from_currency, to_currency, start_date, end_date)
    result = execute_python_script(script)
    
    return [] if result.nil? || result["rates"].nil?
    
    result["rates"].map do |rate_data|
      {
        from: from_currency,
        to: to_currency,
        rate: rate_data["rate"],
        date: Date.parse(rate_data["date"])
      }
    end
  end

  def test_connection
    script = build_test_script
    result = execute_python_script(script)
    result&.fetch("status", false) == "ok"
  end

  private

  def detect_python_path
    %w[python3 python].each do |cmd|
      begin
        result = `which #{cmd} 2>/dev/null`
        return cmd.strip if $?.success? && !result.empty?
      rescue
        next
      end
    end
    
    # Try common paths
    ["/usr/bin/python3", "/usr/local/bin/python3", "/bin/python3"].each do |path|
      return path if File.executable?(path)
    end
    
    nil
  end

  def execute_python_script(script)
    Tempfile.create(["yahoo_finance", ".py"]) do |file|
      file.write(script)
      file.flush

      command = "#{@python_path} #{file.path}"
      
      Rails.logger.debug("Executing Python script for Yahoo Finance")
      
      begin
        output = `#{command} 2>&1`
        
        if $?.success?
          JSON.parse(output.strip)
        else
          Rails.logger.warn("Yahoo Finance Python script failed: #{output}")
          nil
        end
      rescue JSON::ParserError => e
        Rails.logger.warn("Failed to parse Yahoo Finance response: #{e.message}")
        Rails.logger.debug("Raw output: #{output}")
        nil
      rescue => e
        Rails.logger.error("Yahoo Finance service error: #{e.message}")
        nil
      end
    end
  end

  def build_price_script(symbol, date)
    <<~PYTHON
      import yfinance as yf
      import json
      import sys
      from datetime import datetime, timedelta
      import io
      from contextlib import redirect_stdout, redirect_stderr

      def get_price():
          try:
              # Redirect yfinance output to prevent JSON corruption
              output_buffer = io.StringIO()
              error_buffer = io.StringIO()
              
              with redirect_stdout(output_buffer), redirect_stderr(error_buffer):
                  ticker = yf.Ticker("#{symbol}")
                  
                  # Get recent history to find latest price
                  hist = ticker.history(period="5d")
                  
                  if hist.empty:
                      return None
                      
                  latest_price = float(hist['Close'].iloc[-1])
                  
                  # Try to get currency from info
                  info = ticker.info
                  currency = info.get('currency', 'USD')
                  
                  return {
                      "price": latest_price,
                      "currency": currency
                  }
          except Exception as e:
              return None

      result = get_price()
      if result:
          print(json.dumps(result))
      else:
          print(json.dumps({"error": "No data available"}))
    PYTHON
  end

  def build_historical_script(symbol, start_date, end_date)
    <<~PYTHON
      import yfinance as yf
      import json
      import pandas as pd
      from datetime import datetime
      import io
      from contextlib import redirect_stdout, redirect_stderr

      def get_historical_prices():
          try:
              output_buffer = io.StringIO()
              error_buffer = io.StringIO()
              
              with redirect_stdout(output_buffer), redirect_stderr(error_buffer):
                  ticker = yf.Ticker("#{symbol}")
                  
                  hist = ticker.history(start="#{start_date}", end="#{end_date}")
                  
                  if hist.empty:
                      return None
                      
                  prices = []
                  for date, row in hist.iterrows():
                      prices.append({
                          "date": date.strftime("%Y-%m-%d"),
                          "price": float(row['Close'])
                      })
                  
                  # Try to get currency
                  info = ticker.info
                  currency = info.get('currency', 'USD')
                  
                  return {
                      "prices": prices,
                      "currency": currency
                  }
          except Exception as e:
              return None

      result = get_historical_prices()
      if result:
          print(json.dumps(result))
      else:
          print(json.dumps({"error": "No data available"}))
    PYTHON
  end

  def build_info_script(symbol)
    <<~PYTHON
      import yfinance as yf
      import json
      import io
      from contextlib import redirect_stdout, redirect_stderr

      def get_info():
          try:
              output_buffer = io.StringIO()
              error_buffer = io.StringIO()
              
              with redirect_stdout(output_buffer), redirect_stderr(error_buffer):
                  ticker = yf.Ticker("#{symbol}")
                  info = ticker.info
                  
                  return {
                      "name": info.get('longName', info.get('shortName', '#{symbol}')),
                      "currency": info.get('currency', 'USD'),
                      "exchange": info.get('exchange', 'UNKNOWN')
                  }
          except Exception as e:
              return None

      result = get_info()
      if result:
          print(json.dumps(result))
      else:
          print(json.dumps({"error": "No data available"}))
    PYTHON
  end

  def build_exchange_rate_script(from_currency, to_currency, date)
    symbol = "#{from_currency}#{to_currency}=X"
    <<~PYTHON
      import yfinance as yf
      import json
      from datetime import datetime
      import io
      from contextlib import redirect_stdout, redirect_stderr

      def get_exchange_rate():
          try:
              output_buffer = io.StringIO()
              error_buffer = io.StringIO()
              
              with redirect_stdout(output_buffer), redirect_stderr(error_buffer):
                  ticker = yf.Ticker("#{symbol}")
                  
                  # Get recent history to find rate for the date
                  hist = ticker.history(period="5d")
                  
                  if hist.empty:
                      return None
                      
                  # Get the closest available rate
                  latest_rate = float(hist['Close'].iloc[-1])
                  latest_date = hist.index[-1].strftime("%Y-%m-%d")
                  
                  return {
                      "rate": latest_rate,
                      "date": latest_date
                  }
          except Exception as e:
              return None

      result = get_exchange_rate()
      if result:
          print(json.dumps(result))
      else:
          print(json.dumps({"error": "No data available"}))
    PYTHON
  end

  def build_historical_exchange_rate_script(from_currency, to_currency, start_date, end_date)
    symbol = "#{from_currency}#{to_currency}=X"
    <<~PYTHON
      import yfinance as yf
      import json
      from datetime import datetime
      import io
      from contextlib import redirect_stdout, redirect_stderr

      def get_historical_exchange_rates():
          try:
              output_buffer = io.StringIO()
              error_buffer = io.StringIO()
              
              with redirect_stdout(output_buffer), redirect_stderr(error_buffer):
                  ticker = yf.Ticker("#{symbol}")
                  
                  hist = ticker.history(start="#{start_date}", end="#{end_date}")
                  
                  if hist.empty:
                      return None
                      
                  rates = []
                  for date, row in hist.iterrows():
                      rates.append({
                          "date": date.strftime("%Y-%m-%d"),
                          "rate": float(row['Close'])
                      })
                  
                  return {
                      "rates": rates
                  }
          except Exception as e:
              return None

      result = get_historical_exchange_rates()
      if result:
          print(json.dumps(result))
      else:
          print(json.dumps({"error": "No data available"}))
    PYTHON
  end

  def build_test_script
    <<~PYTHON
      import yfinance as yf
      import json
      import io
      from contextlib import redirect_stdout, redirect_stderr

      def test():
          try:
              output_buffer = io.StringIO()
              error_buffer = io.StringIO()
              
              with redirect_stdout(output_buffer), redirect_stderr(error_buffer):
                  # Test with a simple known ticker
                  ticker = yf.Ticker("AAPL")
                  hist = ticker.history(period="1d")
                  
                  return {"status": "ok"} if not hist.empty else {"status": "error"}
          except Exception as e:
              return {"status": "error", "message": str(e)}

      result = test()
      print(json.dumps(result))
    PYTHON
  end
end