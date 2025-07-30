import common
import ../types

import std/[httpclient, logging, options, streams, json]

# --- Internal types for OpenAI API ---

type
  OpenAITextFormat* = object
    `type`*: string
    strict*: Option[bool]
    schema*: Option[JsonNode]

  OpenAIText* = object
    format*: OpenAITextFormat

  OpenAIChatRequest* = object
    model*: string
    input*: seq[ChatMessage]
    text*: OpenAIText
  OpenAIProvider* = ref object of ChatProvider

const ApiUrl = "https://api.openai.com/v1/responses"

# --- Provider Implementation ---

method chat*(provider: OpenAIProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for OpenAI using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json")
  ])

  var requestBody: string
  if jsonMode:
    let schemaNode = schema.get(%*{"type": "object"})
    let textFormat = OpenAITextFormat(`type`: "json_schema", strict: some(true), schema: some(schemaNode))
    let text = OpenAIText(format: textFormat)
    let request = OpenAIChatRequest(model: usedModel, input: messages, text: text)
    requestBody = $(%*request)
  else:
    let textFormat = OpenAITextFormat(`type`: "text", strict: none(bool), schema: none(JsonNode))
    let text = OpenAIText(format: textFormat)
    let request = OpenAIChatRequest(model: usedModel, input: messages, text: text)
    requestBody = $(%*request)

  info "OpenAI Request Body: " & requestBody
  debug "curl -X POST " & ApiUrl & " -H \"Authorization: Bearer " & provider.conf.key & "\" -H \"Content-Type: application/json\" -d '" & requestBody & "'"

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenAI Response Status: " & $response.code
  debug "OpenAI Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenAI API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = to(parseJson(responseBodyContent), ChatResponse)
  if apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len > 0:
    let content = apiResponse.choices[0].message.content
    return ChatResult(content: content, model: usedModel)
  elif apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len == 0:
    let refusal = "empty content"
    return ChatResult(content: "AI Refusal: " & refusal, model: usedModel)
  else:
    let errorMessage = "OpenAI response contained no choices or refusal."
    error errorMessage
    raise newException(ValueError, errorMessage)
