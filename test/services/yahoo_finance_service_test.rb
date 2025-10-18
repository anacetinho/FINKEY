require "test_helper"

class YahooFinanceServiceTest < ActiveSupport::TestCase
  def setup
    @service = YahooFinanceService.new
  end

  test "initializes with python path detection" do
    assert_not_nil @service
  end

  test "builds price script correctly" do
    script = @service.send(:build_price_script, "AAPL", Date.current)
    assert_includes script, "AAPL"
    assert_includes script, "yfinance"
    assert_includes script, "json.dumps"
  end

  test "builds historical script correctly" do
    start_date = 1.week.ago.to_date
    end_date = Date.current
    script = @service.send(:build_historical_script, "AAPL", start_date, end_date)
    
    assert_includes script, "AAPL"
    assert_includes script, start_date.to_s
    assert_includes script, end_date.to_s
  end

  test "builds info script correctly" do
    script = @service.send(:build_info_script, "AAPL")
    assert_includes script, "AAPL"
    assert_includes script, "longName"
    assert_includes script, "currency"
  end

  test "builds test script correctly" do
    script = @service.send(:build_test_script)
    assert_includes script, "AAPL"
    assert_includes script, "status"
  end
end