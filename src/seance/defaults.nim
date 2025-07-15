# This file centralizes default values for the application,
# primarily the default model names for each provider.
import types

const
  DefaultOpenAIModel* = "gpt-4.1-nano-2025-04-14"
  DefaultAnthropicModel* = "claude-3-5-haiku-20241022"
  DefaultGeminiModel* = "gemini-2.5-flash-lite-preview-06-17"

  DefaultProvider* = Gemini
  DefaultModel = DefaultGeminiModel