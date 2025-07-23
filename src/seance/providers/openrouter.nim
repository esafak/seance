import common
import ../types

import std/[httpclient, logging, options, streams]
import jsony

# --- Internal types for OpenRouter API ---
# These model the specific JSON structure for the OpenRouter API.

type
  OpenRouterChatRequest = object
    model: string
    messages: seq[ChatMessage]

  OpenRouterChatChoice = object
    message: ChatMessage

  OpenRouterChatResponse = object
    choices: seq[OpenRouterChatChoice]

# --- Provider Implementation ---

const
  ApiUrl = "https://openrouter.ai/api/v1/chat/completions"
  Referer = "https://github.com/dmadisetti/seance"
  Title = "Seance"

type
  OpenRouterProvider* = ref object of ChatProvider

method chat*(provider: OpenRouterProvider, messages: seq[ChatMessage], model: Option[string] = none(string)): ChatResult =
  ## Implementation of the chat method for OpenRouter using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json"),
    ("HTTP-Referer", Referer),
    ("X-Title", Title)
  ])
  let requestBody = OpenRouterChatRequest(model: usedModel, messages: messages).toJson()

  debug "OpenRouter Request Body: " & requestBody

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenRouter Response Status: " & $response.code
  debug "OpenRouter Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenRouter API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = responseBodyContent.fromJson(OpenRouterChatResponse)
  let content = try: apiResponse.choices[0].message.content
  except IndexDefect:
    let errorMessage = "OpenRouter response contained no choices."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
