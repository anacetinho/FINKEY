# AI Assistant Failure Report

**Date:** 2026-03-17  
**Time of Incident:** 20:30:52 – 20:32:46 UTC  
**Trigger:** User prompt — *"Evaluate investment portfolio"*  
**Outcome:** "Failed to generate response. Please try again." displayed in UI  

---

## 1. Executive Summary

There are **two distinct bugs** that need to be fixed. They are independent but both matter depending on how LM Studio is configured.

| # | Bug | Impact |
|---|---|---|
| **Bug A** | `ai_model` hardcoded as `"gpt-4.1"` in the chat form | **Breaks JIT model loading** in LM Studio |
| **Bug B** | The 4B model produces only `"\n"` (empty response) | **The actual failure** in the current logs |

---

## 2. Bug A — Hardcoded Model Name (JIT Mode Breaker)

### Where it is

**File:** `app/views/messages/_chat_form.html.erb`, **line 11**

```erb
<%# In the future, this will be a dropdown with different AI models %>
<%= f.hidden_field :ai_model, value: "gpt-4.1" %>
```

The `ai_model` field is hardcoded to `"gpt-4.1"` and submitted with every message. This value is stored in the database on the `messages.ai_model` column and flows all the way into the request body sent to LM Studio:

```
_chat_form.html.erb (ai_model = "gpt-4.1")
    ↓ UserMessage saved to DB with ai_model = "gpt-4.1"
    ↓ AssistantResponseJob → Assistant::Responder#get_llm_response (line 65)
    ↓ llm.chat_response(..., model: message.ai_model, ...)
                                      ↑ "gpt-4.1"
    ↓ Provider::Openai#chat_response (line 61)
         effective_model = @custom_model.present? ? @custom_model : model
```

### Why the form says `"gpt-4.1"` but the log shows `"qwen/qwen3.5-4b"`

Looking at the LLM log, the request body shows `"model": "qwen/qwen3.5-4b"`, not `"gpt-4.1"`. This means:
- The `messages.ai_model` database column currently holds `"qwen/qwen3.5-4b"` (likely set from a previous version of the form or a retry that used a different value stored in the DB)
- The `@custom_model` override in `Provider::Openai` is meant to fix this, but it is being bypassed

Tracing `chat_response` in `provider/openai.rb` line 61:
```ruby
effective_model = @custom_model.present? ? @custom_model : model
```
If `effective_model` becomes `"qwen/qwen3.5-4b"` in the actual request, it means `@custom_model` is **nil or blank** at call time, so `model` (i.e. `message.ai_model` = `"qwen/qwen3.5-4b"`) is used directly.

> **Conclusion**: The `@custom_model` override is not working reliably, or the provider is being re-instantiated without the model setting, allowing the raw `message.ai_model` value through.

### Why this breaks JIT model loading

With LM Studio's **"Allow JIT model loading"** enabled, LM Studio uses the `model` field in the request to decide which model to load on demand. If the value is `"qwen/qwen3.5-4b"` (or `"gpt-4.1"`), and LM Studio has no model with that identifier available on disk, it returns:

```json
{
  "error": {
    "message": "No models loaded. Please load a model in the developer page or use the 'lms load' command.",
    "type": "invalid_request_error",
    "param": "model"
  }
}
```

For JIT to work, the `model` field must **exactly match** the identifier LM Studio uses for the loaded model (e.g., `"nvidia/nemotron-3-nano-4b"` or the exact GGUF path identifier).

**The fix**: The app must send the value from `Setting.local_llm_model` as the `model` field in every LM Studio request — not the stale `message.ai_model` value stored in the database.

---

## 3. Bug B — The Model Produces an Empty Response (`"\n"`)

### The context window is NOT the problem

The model has a **40,000 token context window** (LM Studio is configured with `n_ctx = 55,040`). The prompt is only **4,513 tokens**. This is well within limits. Context size is **not** the cause of the failure.

### What actually happens

After processing 4,513 tokens, the model generates a single `"\n"` and terminates. The model fails to produce either:
- A **tool call** (e.g. `get_portfolio_summary()`, `get_holdings()`)
- Any **text response**

### Why the model fails to produce a useful response

The problem is the **quality and training** of the model for structured function calling, not the size of the context window. Specifically:

**1. The tool schema dominates the entire prompt**

Of the ~4,513 tokens in the prompt:
- System instructions: ~300 tokens
- 9 tool definitions: ~4,200 tokens (the rest)
- User message: **4 tokens** ("Evaluate investment portfolio")

Each tool repeats a full list of **44 account names** in enum arrays. This pattern is repeated identically across `get_transactions`, `get_holdings`, `get_trades`, and all other tools. The model is reading thousands of tokens of repetitive account names before ever reaching the actual question.

**2. Nemotron-3-Nano-4B is a small model with limited function-calling capability**

A 4B parameter model is at the edge of what can reliably perform structured function calling (generating syntactically valid JSON tool call objects). Overwhelmed by ~4K tokens of repetitive schema before reaching the user's short question, the model produces a degenerate output.

**3. No GPU offloading**

LM Studio is running the model 100% on CPU (`Num Offload Layers: 0`). This causes the second attempt to take **87 seconds** just to process the prompt. While this doesn't cause the empty response, it indicates the model may not be fitting in GPU VRAM for optimised inference.

**4. `strict: true` not supported**

LM Studio logs `[WARN]: At least one tool has 'strict' set to true. This setting is not yet supported and will be ignored.` This may subtly affect how the model interprets output format requirements.

---

## 4. Full Call Chain (for reference)

```
User submits "Evaluate investment portfolio"
        │
        ▼
messages/_chat_form.html.erb:11
  ai_model = "gpt-4.1"  ← hardcoded (or stale DB value "qwen/qwen3.5-4b")
        │
        ▼
UserMessage saved to DB: ai_model = "gpt-4.1" / "qwen/qwen3.5-4b"
        │
        ▼
AssistantResponseJob → Chat#ask_assistant → Assistant#respond_to(message)
        │
        ▼
Assistant::Responder#get_llm_response (responder.rb:65)
  llm.chat_response(..., model: message.ai_model, ...)
                               ↑ "gpt-4.1" or "qwen/qwen3.5-4b" from DB
        │
        ▼
Provider::Openai#chat_response (openai.rb:61)
  effective_model = @custom_model.present? ? @custom_model : model
  → IF @custom_model = "nvidia/nemotron-3-nano-4b": correct ✅
  → IF @custom_model = nil (re-instantiation issue): uses DB value ❌
        │
        ▼
POST http://192.168.1.116:1234/v1/responses
  { "model": "qwen/qwen3.5-4b", ... }  ← what the log shows
        │
        ▼
LM Studio: ignores model name, serves loaded model (if pre-loaded)
         OR: tries JIT load of "qwen/qwen3.5-4b" → NOT FOUND → ERROR
        │
        ▼
Model processes 4,513-token prompt (4200 tokens = tool schemas)
        │
        ▼
Model outputs: "\n"  ← empty/degenerate response
        │
        ▼
LM Studio: "This operation was aborted" [internal_error]
        │
        ▼
Worker marks job as "done", Rails shows error in UI
```

---

## 5. Issues Summary

| # | Issue | File / Location | Severity | Impact |
|---|---|---|---|---|
| **A** | `ai_model` hardcoded `"gpt-4.1"` in form | `app/views/messages/_chat_form.html.erb:11` | 🔴 Critical | Breaks JIT model loading; stale values persist in DB |
| **A2** | `@custom_model` override not always applied | `app/models/provider/openai.rb:61` | 🔴 Critical | Raw DB `ai_model` value used as model name instead of `Setting.local_llm_model` |
| **B** | Model outputs empty `"\n"` | Model capability / prompt construction | 🔴 Critical | The actual failure — no response generated |
| **B2** | Tool schema too large (44 accounts × 9 tools) | LLM prompt construction | 🟠 High | Overwhelms small model; likely cause of B |
| **C** | `strict: true` not supported by LM Studio | `provider/openai/chat_config.rb` | 🟡 Medium | Warning logged; may affect output |
| **D** | No GPU offloading (100% CPU) | LM Studio settings | 🟡 Medium | 87-second inference on cold start |

---

## 6. Files Investigated

| File | Finding |
|---|---|
| `app/views/messages/_chat_form.html.erb` | `ai_model` hardcoded as `"gpt-4.1"` |
| `app/models/assistant/responder.rb:65` | Passes `message.ai_model` as `model:` to `chat_response` |
| `app/models/provider/openai.rb:61` | `@custom_model` override — only works if provider is instantiated with `Setting.local_llm_model` |
| `app/models/provider/registry.rb:63–94` | Reads `Setting.local_llm_model` to inject `@custom_model` |
| `app/models/setting.rb` | Defines `local_llm_model` field |
| `logs/settings llm.txt` | UI confirms: provider=`local`, model=`nvidia/nemotron-3-nano-4b` |
| `logs/llm log.txt` | Request shows `"model": "qwen/qwen3.5-4b"` → model outputs `"\n"` |

---

*Report updated: 2026-03-17*
