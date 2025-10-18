class Provider::Registry
  include ActiveModel::Validations

  Error = Class.new(StandardError)

  CONCEPTS = %i[exchange_rates securities llm]

  validates :concept, inclusion: { in: CONCEPTS }

  class << self
    def for_concept(concept)
      new(concept.to_sym)
    end

    def get_provider(name)
      send(name)
    rescue NoMethodError
      raise Error.new("Provider '#{name}' not found in registry")
    end

    def plaid_provider_for_region(region)
      region.to_sym == :us ? plaid_us : plaid_eu
    end

    private
      def stripe
        secret_key = ENV["STRIPE_SECRET_KEY"]
        webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

        return nil unless secret_key.present? && webhook_secret.present?

        Provider::Stripe.new(secret_key:, webhook_secret:)
      end

      def synth
        api_key = ENV.fetch("SYNTH_API_KEY", Setting.synth_api_key)

        return nil unless api_key.present?

        Provider::Synth.new(api_key)
      end

      def plaid_us
        config = Rails.application.config.plaid

        return nil unless config.present?

        Provider::Plaid.new(config, region: :us)
      end

      def plaid_eu
        config = Rails.application.config.plaid_eu

        return nil unless config.present?

        Provider::Plaid.new(config, region: :eu)
      end

      def github
        Provider::Github.new
      end

      def openai
        # Return nil if AI assistant is disabled
        return nil unless Setting.ai_assistant_enabled

        provider_type = Setting.ai_provider || "openai"

        if provider_type == "local"
          # Local LLM with OpenAI-compatible endpoint
          base_url = Setting.local_llm_base_url
          model = Setting.local_llm_model

          Rails.logger.info("Provider::Registry: Using local LLM - base_url: #{base_url}, model: #{model}")

          return nil unless base_url.present? && model.present?

          Provider::Openai.new(
            "dummy-key-for-local", # Local LLMs often don't need a real key
            base_url: base_url,
            model: model
          )
        else
          # Standard OpenAI
          access_token = ENV.fetch("OPENAI_ACCESS_TOKEN", Setting.openai_access_token)

          Rails.logger.info("Provider::Registry: Checking OpenAI access token - present: #{access_token.present?}")

          return nil unless access_token.present?

          Rails.logger.info("Provider::Registry: Creating OpenAI provider")
          Provider::Openai.new(access_token)
        end
      end

      def yahoo_finance
        begin
          Provider::YahooFinance.new
        rescue => e
          Rails.logger.warn("YahooFinance provider unavailable: #{e.message}")
          Rails.logger.debug("YahooFinance provider error details: #{e.class.name} - #{e.backtrace&.first}")
          nil
        end
      end
  end

  def initialize(concept)
    @concept = concept
    validate!
  end

  def providers
    available_providers.map { |p| self.class.send(p) }
  end

  def get_provider(name)
    provider_method = available_providers.find { |p| p == name.to_sym }

    raise Error.new("Provider '#{name}' not found for concept: #{concept}") unless provider_method.present?

    self.class.send(provider_method)
  end

  private
    attr_reader :concept

    def available_providers
      case concept
      when :exchange_rates
        %i[yahoo_finance synth]
      when :securities
        %i[yahoo_finance synth]
      when :llm
        %i[openai]
      else
        %i[synth plaid_us plaid_eu github openai yahoo_finance]
      end
    end
end
