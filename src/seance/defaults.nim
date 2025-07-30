# This file centralizes default values for the application,
# primarily the default model names for each provider.
import types
import tables

const
  DefaultProvider* = Gemini

  DefaultModels* : Table[Provider, string] = {
    OpenAI: "gpt-4.1-nano-2025-04-14",
    Anthropic: "claude-3-5-haiku-20241022",
    Gemini: "gemini-2.5-flash-lite-preview-06-17",
    OpenRouter: "z-ai/glm-4.5-air"
  }.toTable

# let DefaultModel* = DefaultModels[DefaultProvider]