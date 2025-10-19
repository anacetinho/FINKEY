class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: :clear_cache

  def show
    # No longer need synth_usage
  end

  def update
    if hosting_params.key?(:require_invite_for_signup)
      Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:synth_api_key)
      Setting.synth_api_key = hosting_params[:synth_api_key]
    end

    if hosting_params.key?(:use_yahoo_finance)
      Setting.use_yahoo_finance = hosting_params[:use_yahoo_finance]
    end

    # AI Assistant settings
    if hosting_params.key?(:ai_assistant_enabled)
      Setting.ai_assistant_enabled = hosting_params[:ai_assistant_enabled]
    end

    if hosting_params.key?(:ai_provider)
      Setting.ai_provider = hosting_params[:ai_provider]
    end

    if hosting_params.key?(:openai_access_token)
      Setting.openai_access_token = hosting_params[:openai_access_token]
    end

    if hosting_params.key?(:local_llm_base_url)
      Setting.local_llm_base_url = hosting_params[:local_llm_base_url]
    end

    if hosting_params.key?(:local_llm_model)
      Setting.local_llm_model = hosting_params[:local_llm_model]
    end

    # Clear Rails cache to ensure settings changes take effect immediately
    # This is necessary because rails-settings-cached gem aggressively caches values
    # Without this, LLM model changes won't be picked up until server restart
    Rails.cache.clear

    redirect_to settings_hosting_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = t(".failure")
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  def update_prices
    begin
      updated_count = update_all_security_prices
      redirect_to settings_hosting_path, notice: "Successfully updated #{updated_count} security prices from Yahoo Finance"
    rescue => e
      Rails.logger.error("Failed to update security prices: #{e.message}")
      redirect_to settings_hosting_path, alert: "Failed to update security prices: #{e.message}"
    end
  end

  private
    def hosting_params
      params.require(:setting).permit(
        :require_invite_for_signup,
        :require_email_confirmation,
        :synth_api_key,
        :use_yahoo_finance,
        :ai_assistant_enabled,
        :ai_provider,
        :openai_access_token,
        :local_llm_base_url,
        :local_llm_model
      )
    end

    def update_all_security_prices
      updated_count = 0
      
      # Get all securities that have been used in holdings or trades
      securities = Security.where(id: Trade.distinct.pluck(:security_id))
      
      securities.find_each do |security|
        begin
          # Skip securities that are known to fail (no fallbacks per user request)
          next if security.offline?

          # Clear any cached price to ensure fresh data
          security.instance_variable_set(:@current_price, nil)

          # Force fresh price fetch from provider (single attempt, no retries)
          price_data = security.find_or_fetch_price(date: Date.current, cache: true, force_refresh: true)

          if price_data&.price.present?
            updated_count += 1
            Rails.logger.info("Updated price for #{security.ticker}: #{price_data.price}")
          end
        rescue => e
          # Mark failing securities as offline to prevent future attempts
          security.update(offline: true) unless security.offline?
          next
        end
      end
      
      # After updating all prices, trigger sync for all investment accounts to recalculate holdings
      if updated_count > 0
        begin
          # Get accounts that have trades without polymorphic eager loading
          trade_entry_ids = Entry.where(entryable_type: 'Trade').distinct.pluck(:account_id)
          accounts_with_trades = Account.where(id: trade_entry_ids)
          Rails.logger.info("Triggering sync for #{accounts_with_trades.count} accounts to recalculate holdings")
          accounts_with_trades.find_each(&:sync_later)
        rescue => e
          Rails.logger.error("Error triggering account syncs: #{e.message}")
          # Fallback: sync all accounts (less efficient but ensures holdings get updated)
          Rails.logger.info("Fallback: triggering sync for all accounts")
          Account.find_each(&:sync_later)
        end
      end
      
      updated_count
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
