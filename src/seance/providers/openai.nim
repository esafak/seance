import common
import ../types

import std/[httpclient, logging, options, streams, json]
import jsony

# --- Internal types for OpenAI API ---

type
  OpenAIProvider* = ref object of ChatProvider

const ApiUrl = "https://api.openai.com/v1/chat/completions"

# --- Provider Implementation ---

method chat*(provider: OpenAIProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false): ChatResult =
  ## Implementation of the chat method for OpenAI using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json")
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
    requestBody = request.toJson()
  else:
    let request = ChatRequest(model: usedModel, messages: messages)
    requestBody = request.toJson()

  debug "OpenAI Request Body: " & requestBody

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenAI Response Status: " & $response.code
  debug "OpenAI Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenAI API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = responseBodyContent.fromJson(ChatResponse)
  let content = try: apiResponse.choices[0].message.content
  except IndexDefect:
    let errorMessage = "OpenAI response contained no choices."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
