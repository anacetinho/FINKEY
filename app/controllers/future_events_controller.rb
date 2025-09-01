class FutureEventsController < ApplicationController
  before_action :set_future_event, only: [:update, :destroy]

  def create
    @future_event = Current.family.future_events.build(future_event_params)
    
    if @future_event.save
      redirect_to forecasts_path, notice: "Future event added successfully."
    else
      redirect_to forecasts_path, alert: @future_event.errors.full_messages.join(", ")
    end
  end

  def update
    if @future_event.update(future_event_params)
      redirect_to forecasts_path, notice: "Future event updated successfully."
    else
      redirect_to forecasts_path, alert: @future_event.errors.full_messages.join(", ")
    end
  end

  def destroy
    @future_event.destroy
    redirect_to forecasts_path, notice: "Future event deleted successfully."
  end

  private

  def set_future_event
    @future_event = Current.family.future_events.find(params[:id])
  end

  def future_event_params
    params.require(:future_event).permit(:name, :date, :amount, :event_type, :description)
  end
end