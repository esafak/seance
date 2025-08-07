import config, logging, options, strutils, tables, types
from defaults import DefaultModels, DefaultProvider

from providers/common import chat, defaultHttpPostHandler
from providers/anthropic import AnthropicProvider
from providers/gemini import GeminiProvider
from providers/openai import OpenAIProvider
from providers/openrouter import OpenRouterProvider
from providers/lmstudio import LMStudioProvider

export ChatProvider, ChatMessage, MessageRole, ChatResult, Provider, chat

proc newProvider*(provider: Option[Provider] = none(Provider), providerConf: Option[ProviderConfig] = none(ProviderConfig)): ChatProvider =
  var finalProviderConf: ProviderConfig
  var usedProvider: Provider

  if providerConf.isSome:
    finalProviderConf = providerConf.get()
    usedProvider = provider.get(DefaultProvider)
  else:
    let config = loadConfig()
    usedProvider = provider.get(config.defaultProvider)
    let providerName = ($usedProvider).normalize()
    if not config.providers.hasKey(providerName):
      if usedProvider == LMStudio:
        finalProviderConf = ProviderConfig(key: "", model: none(string), endpoint: none(string))
      else:
        raise newException(ConfigError, "Provider '" & providerName & "' not found in config.")
    else:
      finalProviderConf = config.providers[providerName]

  if finalProviderConf.key.len == 0 and usedProvider notin [LMStudio]:
    raise newException(ConfigError, "API key for provider '" & $usedProvider & "' is not set.")

  debug "Provider config: " & $finalProviderConf

  case usedProvider
  of Anthropic:
    result = AnthropicProvider(conf: finalProviderConf, defaultModel: DefaultModels[Anthropic], postRequestHandler: defaultHttpPostHandler)
  of Gemini:
    result = GeminiProvider(conf: finalProviderConf, defaultModel: DefaultModels[Gemini], postRequestHandler: defaultHttpPostHandler)
  of OpenAI:
    result = OpenAIProvider(conf: finalProviderConf, defaultModel: DefaultModels[OpenAI], postRequestHandler: defaultHttpPostHandler)
  of OpenRouter:
    result = OpenRouterProvider(conf: finalProviderConf, defaultModel: DefaultModels[OpenRouter], postRequestHandler: defaultHttpPostHandler)
  of LMStudio:
    result = LMStudioProvider(conf: finalProviderConf, defaultModel: DefaultModels[LMStudio], postRequestHandler: defaultHttpPostHandler)
