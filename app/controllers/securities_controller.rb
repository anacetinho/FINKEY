class SecuritiesController < ApplicationController
  def index
    @securities = Security.search_provider(
      params[:q],
      country_code: params[:country_code] == "US" ? "US" : nil
    )
  end

  def update
    @security = Security.find(params[:id])
    if @security.update(security_params)
      redirect_back fallback_location: root_path, notice: "Security updated"
    else
      redirect_back fallback_location: root_path, alert: "Failed to update security"
    end
  end

  private
    def security_params
      params.require(:security).permit(:manual)
    end
end
