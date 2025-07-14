import common
import ../config
import ../defaults

import std/[httpclient, strutils, streams]
import std/logging

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
    conf*: ProviderConfig
    # Use a direct function to perform the POST request, enabling easier mocking
    postRequestHandler: proc(url: string, body: string, headers: HttpHeaders): Response

# Default HTTP POST request handler for production use
proc defaultHttpPostHandler(url: string, body: string, headers: HttpHeaders): Response =
  let client = newHttpClient()
  defer: client.close() # Ensure the client is closed after use
  client.headers = headers # Set the headers on the client object
  result = client.post(url, body = body) # Call post without a 'headers' parameter

proc newOpenAIProvider*(conf: ProviderConfig, postRequestHandler: proc(url: string, body: string, headers: HttpHeaders): Response = nil): OpenAIProvider =
  ## Creates a new instance of the OpenAI provider.
  ## Optionally accepts a custom postRequestHandler for testing or custom HTTP handling.
  let handler = if postRequestHandler == nil:
                  defaultHttpPostHandler # Use the default handler if none is provided
                else:
                  postRequestHandler # Use the provided custom handler
  return OpenAIProvider(conf: conf, postRequestHandler: handler)

method chat*(provider: OpenAIProvider, messages: seq[ChatMessage], model: string = ""): ChatResult =
  ## Implementation of the chat method for OpenAI using a live API call
  # Set authentication headers (these are still specific to the provider)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json")
  ])

  # Determine the model to use
  let modelToUse = if model.len > 0: model else: provider.conf.model
  if modelToUse.len == 0:
    raise newException(ValueError, "Model not specified via argument or config")

  # Create the request body
  let requestBody = OpenAIChatRequest(
    model: modelToUse,
    messages: messages
  ).toJson()

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
  if apiResponse.choices.len == 0:
    let errorMessage = "OpenAI response contained no choices."
    error errorMessage # Log the error
    raise newException(ValueError, errorMessage)

  # Return the first choice's content, including the model used
  return ChatResult(
    content: apiResponse.choices[0].message.content,
    model: modelToUse)