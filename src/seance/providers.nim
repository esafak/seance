import  tables
import config
from providers/common import ChatProvider, ChatMessage, MessageRole, ChatResult, chat
from config import Config, ProviderConfig
from providers/anthropic import AnthropicProvider, newAnthropicProvider
from providers/gemini import GeminiProvider, newGeminiProvider
from providers/openai import OpenAIProvider, newOpenAIProvider

type
  Provider* = enum
    OpenAI,
    Gemini,
    Anthropic

export ChatProvider, ChatMessage, MessageRole, ChatResult, chat,
       AnthropicProvider, newAnthropicProvider,
       GeminiProvider, newGeminiProvider,
       OpenAIProvider, newOpenAIProvider,
       Provider

proc getProvider*(provider: Provider, config: Config): ChatProvider =
  ## Factory function to create a provider instance from its name.
  let providerName = $provider
  if not config.providers.hasKey(providerName):
    raise newException(ConfigError, "Provider not found in config: " & providerName)

  let providerConf = config.providers[providerName]
  if providerConf.key.len == 0:
    raise newException(ConfigError, "API key for provider '" & providerName & "' is not set.")

  case provider
  of Anthropic: return newAnthropicProvider(providerConf)
  of Gemini: return newGeminiProvider(providerConf)
  of OpenAI: return newOpenAIProvider(providerConf)

proc getProvider*(provider: Provider): ChatProvider =
  ## Convenience function that loads the default config and returns a provider.
  let config = loadConfig()
  return getProvider(provider, config)
