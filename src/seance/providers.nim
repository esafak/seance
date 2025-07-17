import config, logging, options, strutils, tables, types

from providers/common import dispatchChat
from providers/anthropic import newAnthropicProvider
from providers/gemini import newGeminiProvider
from providers/openai import newOpenAIProvider

export ChatProvider, ChatMessage, MessageRole, ChatResult, Provider, dispatchChat

proc getProvider*(provider: Option[Provider] = none(Provider), config: SeanceConfig = loadConfig()): ChatProvider =
  ## Instantiates a provider.
  let usedProvider = provider.get(config.defaultProvider)
  let providerName = ($usedProvider).normalize()
  if not config.providers.hasKey(providerName):
    raise newException(ConfigError, "Provider '" & providerName & "' not found in config.")

  # Check only the config for the selected provider
  let providerConf = config.providers[providerName]
  if providerConf.key.len == 0:
    raise newException(ConfigError, "API key for provider '" & providerName & "' is not set.")

  debug "Provider config: " & $providerConf

  case usedProvider:
    of Anthropic: return newAnthropicProvider(providerConf)
    of Gemini: return newGeminiProvider(providerConf)
    of OpenAI: return newOpenAIProvider(providerConf)
