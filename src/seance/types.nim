import httpclient
import strutils
import tables
import json

type
  HttpPostHandler* = proc(url: string, body: string, headers: HttpHeaders): Response

  MessageRole* = enum system, user, assistant

  ChatMessage* = object
    role*: MessageRole
    content*: string

  FunctionDeclaration* = object of RootObj
    name*: string
    description*: string
    parameters*: JsonNode

  Tool* = object of RootObj
    name*: string
    description*: string
    input_schema*: JsonNode

  ChatRequest* = object of RootObj
    model*: string
    messages*: seq[ChatMessage]
    response_format*: JsonNode
    generationConfig*: JsonNode

  ChatResult* = object
    content*: string
    model*: string

  ChatChoice* = object
    message*: ChatMessage

  ChatResponse* = object
    choices*: seq[ChatChoice]
    content*: seq[JsonNode]
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

