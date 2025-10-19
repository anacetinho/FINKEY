# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v2" }

  # Legacy Synth API (deprecated, kept for backward compatibility)
  field :synth_api_key, type: :string, default: ENV["SYNTH_API_KEY"]

  # Yahoo Finance for security prices and exchange rates
  field :use_yahoo_finance, type: :boolean, default: true

  # AI Assistant Configuration
  field :ai_assistant_enabled, type: :boolean, default: false
  field :ai_provider, type: :string, default: "openai" # "openai" or "local"
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :local_llm_base_url, type: :string, default: ""
  field :local_llm_model, type: :string, default: ""

  # User management settings
  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
