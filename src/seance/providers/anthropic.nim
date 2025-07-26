import common
import ../types

import std/[httpclient, logging, options, strutils, streams, json]
import jsony

# --- Internal types for Anthropic API ---
type
  AnthropicContentBlock = object
    `type`: string
    text: string

const
  ApiUrl = "https://api.anthropic.com/v1/messages"
  DefaultMaxTokens* = 1024

type
  AnthropicProvider* = ref object of ChatProvider

method chat*(provider: AnthropicProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false): ChatResult =
  ## Implementation of the chat method for Anthropic.
  let usedModel = provider.getFinalModel(model)
  var requestHeaders = newHttpHeaders([
    ("x-api-key", provider.conf.key),
    ("Content-Type", "application/json"),
    ("anthropic-version", "2023-06-01")
  ])

  if jsonMode:
    requestHeaders.add("anthropic-beta", "tools-2024-04-04")

  let requestBody = ChatRequest(
    model: usedModel,
    messages: messages,
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

  let apiResponse = responseBodyContent.fromJson(ChatResponse)
  if apiResponse.content.len == 0 or apiResponse.content[0]["type"].str != "text":
    let errorMessage = "Anthropic response contained no text content."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(
    content: apiResponse.content[0]["text"].str,
    model: usedModel # apiResponse.model
  )
