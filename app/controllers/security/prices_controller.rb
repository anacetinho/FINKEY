class Security::PricesController < ApplicationController
  def create
    @security = Security.find(params[:security_id])
    @price = @security.prices.find_or_initialize_by(date: Date.current)
    @price.price = price_params[:price]
    @price.currency = price_params[:currency]

    if @price.save
      @security.touch # Trigger cache refresh or similar
      # Need to rematerialize holdings if price changed? Yes.
      account_ids = @security.trades.joins(:entry).pluck("entries.account_id").uniq
      Account.where(id: account_ids).find_each(&:sync_later)

      redirect_back fallback_location: root_path, notice: "Price updated"
    else
      redirect_back fallback_location: root_path, alert: "Failed to update price"
    end
  end

  private
    def price_params
      params.require(:price).permit(:price, :currency)
    end
end
