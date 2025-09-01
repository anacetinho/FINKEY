class UI::ForecastChart < ApplicationComponent
  attr_reader :forecast, :timeline

  def initialize(forecast:, timeline: "1Y")
    @forecast = forecast
    @timeline = timeline
  end

  def current_net_worth_money
    forecast.current_net_worth
  end

  def projected_net_worth_money
    forecast.projected_net_worth
  end

  def projection_change_money
    # Use float arithmetic to avoid CoercedNumeric struct issues
    Money.new(projected_net_worth_money.to_f - current_net_worth_money.to_f, forecast.family.currency)
  end

  def projection_change_percentage
    return 0.0 if current_net_worth_money.to_f == 0
    
    # Ensure we always return a pure numeric value, not a Money object
    result = (projection_change_money.to_f / current_net_worth_money.to_f.abs * 100).round(1)
    result.to_f
  end

  def series
    forecast.forecast_series
  end

  def timeline_options
    [
      ["1 Year", "1Y"],
      ["2 Years", "2Y"], 
      ["5 Years", "5Y"]
    ]
  end

  def timeline_label
    case timeline
    when "1Y"
      "1 year"
    when "2Y"
      "2 years"
    when "5Y"
      "5 years"
    else
      "1 year"
    end
  end

  def projection_trend_class
    if projection_change_money.to_f > 0
      "text-success"
    elsif projection_change_money.to_f < 0
      "text-destructive"
    else
      "text-secondary"
    end
  end

  def projection_trend_icon
    if projection_change_money.to_f > 0
      "trending-up"
    elsif projection_change_money.to_f < 0
      "trending-down"
    else
      "minus"
    end
  end

  def has_data?
    series.values.any?
  end

  def insufficient_data?
    !forecast.has_sufficient_data?
  end
end