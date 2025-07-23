import httpclient
import strutils
import tables

type
  HttpPostHandler* = proc(url: string, body: string, headers: HttpHeaders): Response

  MessageRole* = enum system, user, assistant

  ChatMessage* = object
    role*: MessageRole
    content*: string
    model*: string

  ChatResult* = object
    content*: string
    model*: string

  ChatProvider* = ref object of RootObj
    conf*: ProviderConfig
    defaultModel*: string
    # Separate out to facilitate mocking
    postRequestHandler*: HttpPostHandler

  Provider* = enum
    Anthropic,
    Gemini,
    OpenAI,
    OpenRouter

  ProviderConfig* = object
    key*: string
    model*: string

  SeanceConfig* = object
    providers*: Table[string, ProviderConfig]
    defaultProvider*: Provider
    autoSession*: bool

  ConfigError* = object of CatchableError

proc parseProvider*(providerName: string): Provider =
  case providerName.normalize():
  of "openai": result = OpenAI
  of "gemini": result = Gemini
  of "anthropic": result = Anthropic
  of "openrouter": result = OpenRouter
  else: raise newException(ConfigError, "Unknown provider: " & providerName)

