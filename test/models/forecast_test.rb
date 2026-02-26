require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "initializes with growth rates" do
    forecast = Forecast.new(@family, 
      income_growth_rate: 3.0, 
      expense_growth_rate: 2.0, 
      property_growth_rate: 5.0, 
      investment_growth_rate: 7.0
    )

    assert_equal 0.03, forecast.income_growth_rate
    assert_equal 0.02, forecast.expense_growth_rate
    assert_equal 0.05, forecast.property_growth_rate
    assert_equal 0.07, forecast.investment_growth_rate
  end

  test "calculates forecast series with appreciation" do
    # Mock income and expenses
    IncomeStatement.any_instance.stubs(:median_income).returns(Money.new(1000000, "USD")) # 10,000
    IncomeStatement.any_instance.stubs(:median_expense).returns(Money.new(800000, "USD"))  # 8,000
    
    # Mock net worth series for historical data
    mock_historical_values = [
      Series::Value.new(date: 2.months.ago.to_date, value: 100000),
      Series::Value.new(date: 1.month.ago.to_date, value: 105000),
      Series::Value.new(date: Date.current, value: 110000)
    ]
    mock_series = Series.new(
      start_date: 2.months.ago.to_date,
      end_date: Date.current,
      interval: "1 month",
      values: mock_historical_values
    )
    BalanceSheet.any_instance.stubs(:net_worth_series).returns(mock_series)
    BalanceSheet.any_instance.stubs(:net_worth_money).returns(Money.new(11000000, "USD")) # 110,000

    # Assume we have 1 property of 50k and 1 investment of 30k
    # Residual is 110k - 50k - 30k = 30k
    
    # We need to ensure the accounts in fixtures match our expectations or we stub them
    property_account = accounts(:property)
    property_account.update!(balance: 50000)
    
    investment_account = accounts(:investment)
    investment_account.update!(balance: 30000)
    
    # All other accounts should be 0 or accounted for in residual
    @family.accounts.where.not(id: [property_account.id, investment_account.id]).update_all(balance: 0)
    # Give some balance to depository to make up the residual (30k)
    accounts(:depository).update!(balance: 30000)

    forecast = Forecast.new(@family, 
      timeline: "1Y",
      income_growth_rate: 0, 
      expense_growth_rate: 0, 
      property_growth_rate: 12.0, # 1% per month roughly
      investment_growth_rate: 24.0 # 2% per month roughly
    )

    series = forecast.forecast_series
    
    # 12 months forecast + 3 historical
    assert_equal 15, series.values.size
    
    # Check first forecast month (index 3)
    # Month 1:
    # Property: 50,000 * (1.12^(1/12)) ~= 50k * 1.009488 ~= 50474
    # Investment: 30,000 * (1.24^(1/12)) ~= 30k * 1.018087 ~= 30542
    # Cash Flow: 10,000 - 8,000 = 2,000
    # Residual: 30,000 + 2,000 = 32,000
    # Total: 50474 + 30542 + 32000 = 113016
    
    first_forecast = series.values[3]
    assert_in_delta 113016, first_forecast.value, 100 # Allow some rounding slack
  end
end
