class Provider::Openai < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Openai::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[gpt-4.1]

  def initialize(access_token, base_url: nil, model: nil)
    Rails.logger.info("Provider::Openai: Initializing with token present: #{access_token.present?}")

    client_options = { access_token: access_token }

    # Support for custom base URL (local LLMs)
    if base_url.present?
      # ruby-openai gem appends /v1 internally, so we strip it if the user provided it 
      # to prevent double /v1/v1 paths. We also strip trailing slashes.
      sanitized_base_url = base_url.strip.chomp("/").chomp("/v1")
      
      client_options[:uri_base] = sanitized_base_url
      client_options[:api_version] = "v1" # Ensure we use v1
      
      Rails.logger.info("Provider::Openai: Using custom base URL: #{sanitized_base_url}")
    end

    @client = ::OpenAI::Client.new(client_options)
    @custom_model = model # Store custom model for local LLMs
    Rails.logger.info("Provider::Openai: Client initialized successfully")
  rescue => e
    Rails.logger.error("Provider::Openai: Failed to initialize client: #{e.message}")
    raise
  end

  def supports_model?(model)
    # If using a custom model (local LLM), accept any model
    return true if @custom_model.present?

    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        model: @custom_model,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        model: @custom_model,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    # For local LLMs, @custom_model is always authoritative — never use the
    # stale ai_model value stored on the message record.
    # For standard OpenAI, fall back to the model kwarg (which comes from settings via the form).
    effective_model = @custom_model.presence || model

    Rails.logger.info("Provider::Openai: Starting chat_response with model: #{effective_model}")
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      # standard OpenAI uses 'messages' and includes instructions as a system message
      messages = chat_config.build_messages(prompt, instructions: instructions)

      parameters = {
        model: effective_model,
        messages: messages,
        tools: chat_config.tools.presence,
        max_tokens: 12276, # Give enough room for reasoning + answer
      }.compact

      if streamer.present?
        full_content = ""
        tool_calls_accumulator = {}
        response_id = nil

        parameters[:stream] = proc do |chunk|
          response_id ||= chunk.dig("id")
          parsed_chunk = ChatStreamParser.new(chunk).parsed
          
          if parsed_chunk.present?
            case parsed_chunk.type
            when "output_text"
              full_content += parsed_chunk.data
              streamer.call(parsed_chunk)
            when "tool_call"
              delta = parsed_chunk.data
              index = delta["index"]
              
              tool_calls_accumulator[index] ||= { "id" => nil, "function" => { "name" => "", "arguments" => "" } }
              
              # Accumulate delta into the specific tool call index
              tool_calls_accumulator[index]["id"] = delta["id"] if delta["id"]
              if delta["function"]
                tool_calls_accumulator[index]["function"]["name"] += delta["function"]["name"] if delta["function"]["name"]
                tool_calls_accumulator[index]["function"]["arguments"] += delta["function"]["arguments"] if delta["function"]["arguments"]
              end
              
              # We don't call the streamer for tool calls as the Responder usually doesn't show them in real-time
            end
          end
        end
        
        raw_response = client.chat(parameters: parameters)
        
        # Convert accumulated tool calls to ChatFunctionRequest objects
        function_requests = tool_calls_accumulator.values.map do |tc|
          ChatFunctionRequest.new(
            id: tc["id"],
            call_id: tc["id"],
            function_name: tc["function"]["name"],
            function_args: tc["function"]["arguments"]
          )
        end

        final_response = ChatResponse.new(
          id: response_id || "streamed", 
          model: effective_model, 
          messages: [ ChatMessage.new(id: response_id, output_text: full_content) ], 
          function_requests: function_requests
        )

        # Notify the streamer that the response is complete and provide the final object
        streamer.call(ChatStreamChunk.new(type: "response", data: final_response))

        final_response
      else
        raw_response = client.chat(parameters: parameters)
        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client
end
