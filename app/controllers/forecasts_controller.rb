class ForecastsController < ApplicationController
  before_action :set_forecast_params

  def index
    @forecast = Current.family.forecast(
      timeline: @timeline,
      income_growth_rate: @income_growth_rate,
      expense_growth_rate: @expense_growth_rate
    )
    
    @has_sufficient_data = @forecast.has_sufficient_data?

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  rescue => e
    Rails.logger.error "Forecast error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Fallback to basic forecast with default parameters
    @forecast = Current.family.forecast(timeline: "1Y")
    @has_sufficient_data = false
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def set_forecast_params
    @timeline = params[:timeline] || "1Y"
    @income_growth_rate = params[:income_growth_rate].to_f
    @expense_growth_rate = params[:expense_growth_rate].to_f
    
    # Validate timeline parameter
    unless %w[1Y 2Y 5Y].include?(@timeline)
      @timeline = "1Y"
    end
    
    # Cap growth rates to reasonable ranges
    @income_growth_rate = @income_growth_rate.clamp(-50.0, 100.0)
    @expense_growth_rate = @expense_growth_rate.clamp(-50.0, 100.0)
  end
end