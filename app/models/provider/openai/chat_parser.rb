class Provider::Openai::ChatParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      object.dig("id")
    end

    def response_model
      object.dig("model")
    end

    def messages
      choices = object.dig("choices") || []
      
      choices.map do |choice|
        message = choice.dig("message")
        next if message.nil?

        content = message.dig("content")
        reasoning = message.dig("reasoning_content")
        
        # Combine reasoning and content if both are present
        output_text = [ 
          (reasoning.present? ? "> Thought: #{reasoning}" : nil), 
          content 
        ].compact.join("\n\n")

        next if output_text.blank?

        ChatMessage.new(
          id: response_id, 
          output_text: output_text
        )
      end.compact
    end

    def function_requests
      choices = object.dig("choices") || []
      tool_calls = choices.flat_map { |c| c.dig("message", "tool_calls") }.compact

      tool_calls.map do |tool_call|
        ChatFunctionRequest.new(
          id: tool_call.dig("id"),
          call_id: tool_call.dig("id"), # In Chat Completions, id and call_id are often the same
          function_name: tool_call.dig("function", "name"),
          function_args: JSON.parse(tool_call.dig("function", "arguments"))
        )
      end
    end
end
