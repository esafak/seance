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

type
  ToolChoice* = object of RootObj
    `type`*: string
    name*: string

  AnthropicChatRequest* = object of RootObj
    model*: string
    messages*: seq[ChatMessage]
    max_tokens*: int
    tools*: seq[Tool]
    tool_choice*: ToolChoice

proc generateSchema(typeName: string): (Tool, ToolChoice) =
  let properties = newJObject()
  properties[typeName] = %newJObject()
  let schema = %*{"type": "object", "properties": properties}
  let tool = Tool(name: "extract_" & typeName, description: "Extract " & typeName & " from the text.", input_schema: schema)
  let toolChoice = ToolChoice(`type`: "tool", name: "extract_" & typeName)
  return (tool, toolChoice)

method chat*(provider: AnthropicProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for Anthropic.
  let usedModel = provider.getFinalModel(model)
  var requestHeaders = newHttpHeaders([
    ("x-api-key", provider.conf.key),
    ("Content-Type", "application/json"),
    ("anthropic-version", "2023-06-01")
  ])

  var requestBody: string
  if jsonMode:
    requestHeaders.add("anthropic-beta", "tools-2024-04-04")
    let (tool, toolChoice) = generateSchema("recipe")
    requestBody = AnthropicChatRequest(
      model: usedModel,
      messages: messages,
      max_tokens: DefaultMaxTokens,
      tools: @[tool],
      tool_choice: toolChoice
    ).toJson()
  else:
    let request = AnthropicChatRequest(
      model: usedModel,
      messages: messages,
      max_tokens: DefaultMaxTokens
    )
    var jsonRequest = parseJson(request.toJson())
    jsonRequest.delete("tools")
    jsonRequest.delete("tool_choice")
    requestBody = jsonRequest.pretty()

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
  if apiResponse.content.len == 0:
    let errorMessage = "Anthropic response contained no content."
    error errorMessage
    raise newException(ValueError, errorMessage)

  var content = ""
  for contentBlock in apiResponse.content:
    if contentBlock["type"].str == "text":
      content = contentBlock["text"].str
      break
    elif contentBlock["type"].str == "tool_use":
      content = contentBlock["input"].pretty()
      break

  if content.len == 0:
    let errorMessage = "Anthropic response contained no text or tool_use content."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(
    content: content,
    model: usedModel # apiResponse.model
  )
