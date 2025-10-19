class Assistant::Function::GetForecast < Assistant::Function
  include ActiveSupport::NumberHelper

  class << self
    def name
      "get_forecast"
    end

    def description
      <<~INSTRUCTIONS
        Use this to get the user's financial forecast with projected net worth based on their income and expense trends.
        This function provides both current financial status and future projections over a specified timeline.

        You can optionally specify growth rates for income and expenses to model different scenarios.
      INSTRUCTIONS
    end
  end

  def call(params = {})
    timeline = params["timeline"] || "1Y"
    income_growth_rate = params["income_growth_rate"] || 0.0
    expense_growth_rate = params["expense_growth_rate"] || 0.0

    forecast = family.forecast(
      timeline: timeline,
      income_growth_rate: income_growth_rate,
      expense_growth_rate: expense_growth_rate
    )

    # Get future events within the timeline
    timeline_months = case timeline
    when "1Y" then 12
    when "2Y" then 24
    when "5Y" then 60
    else 12
    end

    timeline_end = Date.current + timeline_months.months
    future_events = family.future_events.where(date: Date.current..timeline_end).order(:date)

    {
      as_of_date: Date.current,
      timeline: timeline,
      has_sufficient_data: forecast.has_sufficient_data?,
      current_net_worth: forecast.current_net_worth.format,
      projected_net_worth: forecast.projected_net_worth.format,
      projected_change: (forecast.projected_net_worth - forecast.current_net_worth).format,
      monthly_income: forecast.monthly_income.format,
      monthly_expenses: forecast.monthly_expenses.format,
      monthly_cash_flow: forecast.monthly_cash_flow.format,
      total_projected_cash_flow: forecast.total_projected_cash_flow.format,
      income_growth_rate: income_growth_rate,
      expense_growth_rate: expense_growth_rate,
      forecast_series: to_ai_forecast_series(forecast.forecast_series),
      future_events: future_events.map { |event|
        {
          date: event.date,
          amount: Money.new(event.amount, family.currency).format,
          type: event.income? ? "income" : "expense",
          description: event.description
        }
      }
    }
  end

  private
    def params_schema
      build_schema(
        properties: {
          timeline: {
            type: "string",
            description: "The forecast timeline: '1Y' (12 months), '2Y' (24 months), or '5Y' (60 months)",
            enum: [ "1Y", "2Y", "5Y" ]
          },
          income_growth_rate: {
            type: "number",
            description: "Expected annual income growth rate as a percentage (e.g., 5.0 for 5% growth)"
          },
          expense_growth_rate: {
            type: "number",
            description: "Expected annual expense growth rate as a percentage (e.g., 3.0 for 3% growth)"
          }
        },
        required: []
      )
    end

    def strict_mode?
      false
    end

    # Enhanced version of to_ai_time_series that includes both dates and values
    # for better AI understanding of the forecast timeline
    def to_ai_forecast_series(series)
      {
        start_date: series.start_date,
        end_date: series.end_date,
        interval: series.interval,
        data_points: series.values.map { |v|
          {
            date: v.date,
            value: Money.new(v.value, family.currency).format
          }
        }
      }
    end
end
