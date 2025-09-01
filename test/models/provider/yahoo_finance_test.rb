require "test_helper"

class Provider::YahooFinanceTest < ActiveSupport::TestCase
  def setup
    # Mock the YahooFinanceService to avoid actual network calls
    @mock_service = Minitest::Mock.new
    @provider = Provider::YahooFinance.new
    @provider.instance_variable_set(:@service, @mock_service)
  end

  test "implements SecurityConcept interface" do
    assert_includes Provider::YahooFinance.included_modules, Provider::SecurityConcept
  end

  test "formats US symbols correctly" do
    result = @provider.send(:format_symbol_for_yahoo, "AAPL", nil)
    assert_equal "AAPL", result
    
    result = @provider.send(:format_symbol_for_yahoo, "AAPL", "XNAS")
    assert_equal "AAPL", result
  end

  test "formats international symbols correctly" do
    test_cases = {
      "XLON" => ".L",
      "XAMS" => ".AS", 
      "XPAR" => ".PA",
      "XETR" => ".DE",
      "XSWX" => ".SW",
      "XMIL" => ".MI",
      "XMAD" => ".MC"
    }
    
    test_cases.each do |mic, suffix|
      result = @provider.send(:format_symbol_for_yahoo, "TEST", mic)
      assert_equal "TEST#{suffix}", result
    end
  end

  test "maps exchange names to MIC codes" do
    test_cases = {
      "NYSE" => "XNYS",
      "NASDAQ" => "XNAS",
      "LONDON" => "XLON",
      "AMSTERDAM" => "XAMS",
      "PARIS" => "XPAR"
    }
    
    test_cases.each do |exchange, mic|
      result = @provider.send(:map_exchange_to_mic, exchange)
      assert_equal mic, result
    end
  end

  test "search_securities returns array" do
    @mock_service.expect(:fetch_security_info, {
      name: "Apple Inc.",
      currency: "USD", 
      exchange: "NASDAQ"
    }, ["AAPL"])
    
    result = @provider.search_securities("AAPL")
    
    assert result.success?
    assert_instance_of Array, result.data
    assert_equal 1, result.data.length
    assert_equal "AAPL", result.data.first.symbol
    
    @mock_service.verify
  end

  test "fetch_security_price returns price data" do
    @mock_service.expect(:fetch_current_price, {
      price: 150.0,
      currency: "USD"
    }, ["AAPL"])
    
    result = @provider.fetch_security_price(symbol: "AAPL", date: Date.current)
    
    assert result.success?
    assert_instance_of Provider::SecurityConcept::Price, result.data
    assert_equal "AAPL", result.data.symbol
    assert_equal 150.0, result.data.price
    
    @mock_service.verify
  end

  test "handles service errors gracefully" do
    @mock_service.expect(:fetch_current_price, nil, ["INVALID"])
    
    result = @provider.fetch_security_price(symbol: "INVALID", date: Date.current)
    
    assert result.success?
    assert_nil result.data
    
    @mock_service.verify
  end
end