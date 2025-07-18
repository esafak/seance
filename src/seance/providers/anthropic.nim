import common
import ../defaults
import ../types

import std/[httpclient, logging, options, strutils, streams, tables]
import jsony

# --- Internal types for Anthropic API ---
type
  AnthropicChatRequest = object
    model: string
    messages: seq[ChatMessage]
    max_tokens: int

  AnthropicContentBlock = object
    `type`: string
    text: string

  AnthropicChatResponse = object
    content: seq[AnthropicContentBlock]
    model: string

const
  ApiUrl = "https://api.anthropic.com/v1/messages"
  DefaultMaxTokens* = 1024

type
  AnthropicProvider* = ref object of ChatProvider

proc newAnthropicProvider*(conf: ProviderConfig, postRequestHandler: HttpPostHandler = defaultHttpPostHandler): AnthropicProvider =
  ## Creates a new instance of the Anthropic provider.
  return AnthropicProvider(conf: conf, postRequestHandler: postRequestHandler, defaultModel: DefaultModels[Anthropic])

method chat*(provider: AnthropicProvider, messages: seq[ChatMessage], model: Option[string] = none(string)): ChatResult =
  ## Implementation of the chat method for Anthropic.
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("x-api-key", provider.conf.key),
    ("Content-Type", "application/json"),
    ("anthropic-version", "2023-06-01")
  ])
  let requestBody = AnthropicChatRequest(
    model: usedModel,
    messages: messages,
    max_tokens: DefaultMaxTokens
  ).toJson()

  debug "Anthropic Request Body: " & requestBody

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "Anthropic Response Status: " & $response.status
  debug "Anthropic Response Body: " & responseBodyContent

  if response.status.split(' ')[0].parseInt() notin 200..299:
    let errorMessage = "Anthropic API Error " & response.status & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = responseBodyContent.fromJson(AnthropicChatResponse)
  if apiResponse.content.len == 0 or apiResponse.content[0].`type` != "text":
    let errorMessage = "Anthropic response contained no text content."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(
    content: apiResponse.content[0].text,
    model: usedModel # apiResponse.model
  )
