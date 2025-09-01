class Assistant
  include Provided, Configurable, Broadcastable

  attr_reader :chat, :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], functions: config[:functions])
    end
  end

  def initialize(chat, instructions: nil, functions: [])
    @chat = chat
    @instructions = instructions
    @functions = functions
  end

  def respond_to(message)
    Rails.logger.info("Assistant: Starting response for message #{message.id}")
    
    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model
    )

    llm_provider = get_model_provider(message.ai_model)
    Rails.logger.info("Assistant: Got LLM provider: #{llm_provider.class.name if llm_provider}")
    
    unless llm_provider
      Rails.logger.error("Assistant: No LLM provider found for model #{message.ai_model}")
      raise "No LLM provider available for model #{message.ai_model}"
    end

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_tool_caller: function_tool_caller,
      llm: llm_provider
    )

    latest_response_id = chat.latest_assistant_response_id

    responder.on(:output_text) do |text|
      if assistant_message.content.blank?
        stop_thinking

        Chat.transaction do
          assistant_message.append_text!(text)
          chat.update_latest_response!(latest_response_id)
        end
      else
        assistant_message.append_text!(text)
      end
    end

    responder.on(:response) do |data|
      update_thinking("Analyzing your data...")

      if data[:function_tool_calls].present?
        assistant_message.tool_calls = data[:function_tool_calls]
        latest_response_id = data[:id]
      else
        chat.update_latest_response!(data[:id])
      end
    end

    responder.respond(previous_response_id: latest_response_id)
  rescue => e
    stop_thinking
    chat.add_error(e)
  end

  private
    attr_reader :functions

    def function_tool_caller
      function_instances = functions.map do |fn|
        fn.new(chat.user)
      end

      @function_tool_caller ||= FunctionToolCaller.new(function_instances)
    end
end
