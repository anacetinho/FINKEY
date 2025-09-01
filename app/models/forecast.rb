class Forecast
  
  attr_reader :family, :timeline, :income_growth_rate, :expense_growth_rate

  def initialize(family, timeline: "1Y", income_growth_rate: 0.0, expense_growth_rate: 0.0)
    @family = family
    @timeline = timeline
    @income_growth_rate = income_growth_rate.to_f / 100.0  # Convert percentage to decimal
    @expense_growth_rate = expense_growth_rate.to_f / 100.0
  end

  def current_net_worth
    family.balance_sheet.net_worth_money
  end

  def projected_net_worth
    # Get the final projected value from the forecast series to ensure consistency
    series = forecast_series
    return current_net_worth if series.values.empty?
    
    # The last value in the forecast series is our projected net worth
    final_value = series.values.last
    
    # Handle both Hash and Series::Value struct formats
    if final_value.respond_to?(:value)
      # Series::Value struct format
      final_amount = final_value.value
    else
      # Hash format  
      final_amount = final_value[:value]
    end
    
    Money.new(final_amount, family.currency)
  end

  def monthly_income
    raw_amount = family.income_statement.median_income(interval: "month") || 0
    Money.new(raw_amount, family.currency)
  end

  def monthly_expenses  
    raw_amount = family.income_statement.median_expense(interval: "month") || 0
    Money.new(raw_amount.abs, family.currency)
  end

  def monthly_cash_flow
    # Use float arithmetic to avoid CoercedNumeric struct issues
    Money.new(monthly_income.to_f - monthly_expenses.to_f, family.currency)
  end

  def total_projected_cash_flow
    base_monthly_flow = monthly_cash_flow
    return Money.new(0, family.currency) if base_monthly_flow.to_f == 0

    # Convert annual growth rates to monthly compound rates for proper compounding
    monthly_income_rate = (1 + income_growth_rate) ** (1.0/12) - 1
    monthly_expense_rate = (1 + expense_growth_rate) ** (1.0/12) - 1
    
    # Apply monthly compound rates to income and expenses separately
    projected_income_amount = monthly_income.to_f * (1 + monthly_income_rate)
    projected_expenses_amount = monthly_expenses.to_f * (1 + monthly_expense_rate)
    
    # Create Money object from final float result
    Money.new(projected_income_amount - projected_expenses_amount, family.currency)
  end

  def forecast_series
    # Get 2 years of historical data to show proper context before forecast
    historical_period = Period.custom(start_date: 2.years.ago.beginning_of_month.to_date, end_date: Date.current.end_of_month.to_date)
    historical_series = family.balance_sheet.net_worth_series(period: historical_period)
    return historical_series if historical_series.values.empty?

    # Get the last known net worth value as starting point
    last_value = historical_series.values.last
    
    # Handle both Hash and Series::Value struct formats
    if last_value.respond_to?(:date)
      # Series::Value struct format
      last_date = last_value.date
      current_net_worth = last_value.value
    else
      # Hash format
      last_date = last_value[:date]
      current_net_worth = last_value[:value]
    end

    # Generate forecast values with proper compounding
    forecast_values = []
    base_monthly_income = monthly_income.to_f
    base_monthly_expenses = monthly_expenses.to_f
    running_net_worth = current_net_worth.to_f
    
    # Convert annual growth rates to monthly compound rates
    monthly_income_rate = (1 + income_growth_rate) ** (1.0/12) - 1
    monthly_expense_rate = (1 + expense_growth_rate) ** (1.0/12) - 1
    
    # Get future events within the timeline
    timeline_end = Date.parse(last_date.to_s) + months_in_timeline.months
    future_events = family.future_events.where(date: Date.current..timeline_end).order(:date)

    (1..months_in_timeline).each do |month|
      forecast_date = Date.parse(last_date.to_s) + month.months
      
      # Calculate compounded cash flow for this specific month
      compounded_income = base_monthly_income * ((1 + monthly_income_rate) ** month)
      compounded_expenses = base_monthly_expenses * ((1 + monthly_expense_rate) ** month)
      monthly_flow = compounded_income - compounded_expenses
      
      # Add monthly cash flow with proper compounding
      running_net_worth += monthly_flow
      
      # Add any future events that occur in this month
      events_this_month = future_events.select { |event| event.date.month == forecast_date.month && event.date.year == forecast_date.year }
      events_this_month.each do |event|
        if event.income?
          running_net_worth += event.amount.to_f
        else
          running_net_worth -= event.amount.to_f
        end
      end
      
      # Create Series::Value struct instead of Hash to maintain consistency
      forecast_values << Series::Value.new(
        date: forecast_date,
        date_formatted: I18n.l(forecast_date, format: :long),
        value: running_net_worth,
        trend: nil
      )
    end

    # Combine historical and forecast data
    Series.new(
      start_date: historical_series.start_date,
      end_date: forecast_values.last.date,
      interval: historical_series.interval,
      values: historical_series.values + forecast_values
    )
  end

  def has_sufficient_data?
    family.balance_sheet.net_worth_series.values.size >= 3 && 
    monthly_income.to_f != 0 && 
    monthly_expenses.to_f != 0
  end

  private

  def months_in_timeline
    case timeline
    when "1Y"
      12
    when "2Y"  
      24
    when "5Y"
      60
    else
      12
    end
  end
end