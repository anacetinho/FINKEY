module ChatsHelper
  def chat_frame
    :sidebar_chat
  end

  def chat_view_path(chat)
    return new_chat_path if params[:chat_view] == "new"
    return chats_path if chat.nil? || params[:chat_view] == "all"

    chat.persisted? ? chat_path(chat) : new_chat_path
  end

  # Returns the model name that should be sent with every chat request.
  # Always derived from application settings — never hardcoded.
  def configured_ai_model
    if Setting.ai_provider == "local"
      Setting.local_llm_model
    else
      Setting.openai_model
    end
  end
end
