class Provider::Openai::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    choice = object.dig("choices", 0)
    return nil if choice.nil?

    delta = choice.dig("delta")
    return nil if delta.nil?

    if delta["content"].present?
      Chunk.new(type: "output_text", data: delta["content"])
    elsif delta["reasoning_content"].present?
      # Many local LLMs output reasoning in this field. We'll treat it as output text for now 
      # but could theoretically treat it differently in the UI.
      Chunk.new(type: "output_text", data: delta["reasoning_content"])
    elsif delta["tool_calls"].present?
      tool_call_delta = delta["tool_calls"][0]
      
      # We return the raw delta hash for the provider to accumulate
      Chunk.new(type: "tool_call", data: tool_call_delta)
    elsif choice["finish_reason"].present?
      nil
    end
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk

    def parse_response(response)
      Provider::Openai::ChatParser.new(response).parsed
    end
end
