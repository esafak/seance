import common
import ../types

import std/[httpclient, logging, options, streams, json]

# --- Internal types for OpenRouter API ---
type
  OpenRouterProvider* = ref object of ChatProvider

const
  ApiUrl = "https://openrouter.ai/api/v1/chat/completions"
  Referer = "https://github.com/dmadisetti/seance"
  Title = "Seance"

# --- Provider Implementation ---

method chat*(provider: OpenRouterProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for OpenRouter using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json"),
    ("HTTP-Referer", Referer),
    ("X-Title", Title)
  ])

  var requestBody: string
  if jsonMode:
    var response_format = newJObject()
    response_format["type"] = %"json_object"
    let request = ChatRequest(
      model: usedModel,
      messages: messages,
      response_format: response_format
    )
    requestBody = $(%*request)
  else:
    let request = ChatRequest(model: usedModel, messages: messages)
    requestBody = $(%*request)

  debug "OpenRouter Request Body: " & requestBody

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenRouter Response Status: " & $response.code
  debug "OpenRouter Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenRouter API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = to(parseJson(responseBodyContent), ChatResponse)
  let content = try: apiResponse.choices[0].message.content
  except IndexDefect:
    let errorMessage = "OpenRouter response contained no choices."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
