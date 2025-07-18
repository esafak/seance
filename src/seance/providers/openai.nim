import common
import ../defaults
import ../types

import std/[httpclient, logging, options, strutils, streams, tables]
import jsony

# --- Internal types for OpenAI API ---
# These model the specific JSON structure for the OpenAI API.

type
  OpenAIChatRequest = object
    model: string
    messages: seq[ChatMessage]
    # stream: bool # for later

  OpenAIChatChoice = object
    message: ChatMessage

  OpenAIChatResponse = object
    choices: seq[OpenAIChatChoice]

# --- Provider Implementation ---

const ApiUrl = "https://api.openai.com/v1/chat/completions"

type
  OpenAIProvider* = ref object of ChatProvider

proc newOpenAIProvider*(conf: ProviderConfig, postRequestHandler: HttpPostHandler = defaultHttpPostHandler): OpenAIProvider =
  ## Creates a new instance of the OpenAI provider.
  return OpenAIProvider(conf: conf, postRequestHandler: postRequestHandler, defaultModel: DefaultModels[OpenAI])

method chat*(provider: OpenAIProvider, messages: seq[ChatMessage], model: Option[string] = none(string)): ChatResult =
  ## Implementation of the chat method for OpenAI using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json")
  ])
  let requestBody = OpenAIChatRequest(model: usedModel, messages: messages).toJson()

  debug "OpenAI Request Body: " & requestBody

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenAI Response Status: " & $response.code
  debug "OpenAI Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenAI API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = responseBodyContent.fromJson(OpenAIChatResponse)
  let content = try: apiResponse.choices[0].message.content
  except IndexDefect:
    let errorMessage = "OpenAI response contained no choices."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
