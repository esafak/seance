import common
import ../defaults
import ../types

import std/[httpclient, logging, options, strutils, streams]
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
  return OpenAIProvider(conf: conf, postRequestHandler: postRequestHandler, defaultModel: DefaultOpenAIModel)

method dispatchChat*(provider: OpenAIProvider, messages: seq[ChatMessage], model: Option[string] = none(string)): ChatResult =
  ## Implementation of the chat method for OpenAI using a live API call
  # Set authentication headers (these are still specific to the provider)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json")
  ])

  let usedModel = provider.getFinalModel(model)

# Create the request body
  let requestBody = OpenAIChatRequest(model: usedModel, messages: messages).toJson()

  debug "OpenAI Request Body: " & requestBody # Log the request body
  # Corrected hasKey usage for HttpHeaders
  debug "Does requestHeaders contain Authorization BEFORE send? " & $hasKey(requestHeaders, "Authorization")

  # Make the API call using the injected handler
  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)

  # Explicitly call streams.readAll to ensure the correct overload is used
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenAI Response Status: " & $response.code # Log response status
  debug "OpenAI Response Body: " & responseBodyContent # Log the full response body

  # Handle HTTP errors
  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenAI API Error " & $response.code & ": " & responseBodyContent
    error errorMessage # Log the error
    raise newException(IOError, errorMessage)

  # Parse the JSON response
  let apiResponse = responseBodyContent.fromJson(OpenAIChatResponse)
  let content = try: apiResponse.choices[0].message.content
    except IndexDefect:
      let errorMessage = "OpenAI response contained no choices."
      error errorMessage # Log the error
      raise newException(ValueError, errorMessage)

  # Return the first choice's content, including the model used
  return ChatResult(content: content, model: usedModel)
