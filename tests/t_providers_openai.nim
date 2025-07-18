import unittest
import std/json
import std/options
import std/streams # For newStringStream
import std/httpclient
import std/logging

import seance/types
import seance/defaults
import seance/providers/openai # This imports and re-exports symbols from common.nim and openai.nim

# --- Manual Mocking Setup for HTTP POST Request ---
# These global variables will store the mock response and captured request details.

var mockHttpResponse: Response # Stores the response our mock handler will return
var capturedUrl: string       # Captures the URL passed to the mock handler
var capturedRequestBody: string      # Renamed for clarity: Captures the body passed to the mock handler
var capturedHeaders: HttpHeaders # Captures the headers passed to the mock handler

# This is our custom mock POST request handler
proc mockPostRequestHandler(url: string, requestBodyStr: string, headers: HttpHeaders): Response =
  # Replace echo with debug calls
  debug "--- Inside mockPostRequestHandler ---"
  debug "Received Headers in mock: " & $headers
  debug "Does received headers contain Authorization? " & $hasKey(headers, "Authorization")

  # Capture details for assertions later
  capturedUrl = url
  capturedRequestBody = requestBodyStr # Assign to the renamed variable
  capturedHeaders = headers
  # Return the predefined mock response
  return mockHttpResponse

# --- Test Suites ---

suite "OpenAI Provider":
  # Common setup for OpenAI provider tests
  let defaultConf: ProviderConfig = ProviderConfig(key: "test-key", model: "")

  let testMessages = @[
    ChatMessage(role: system, content: "You are a test assistant."),
    ChatMessage(role: user, content: "What is the capital of testing?")
  ]

  setup:
    # Reset mock and captured variables before each test in this suite
    mockHttpResponse = Response()
    capturedUrl = ""
    capturedRequestBody = "" # Reset the renamed variable
    capturedHeaders = newHttpHeaders()

    # Configure logging for tests:
    # Create a new console logger that only shows messages at or above 'info' level.
    # This will hide the 'debug' messages from mockPostRequestHandler.
    # We add it to ensure it's active for this suite.
    addHandler(newConsoleLogger(levelThreshold = lvlInfo))

  teardown:
    # Optional: If you have many test suites and want to ensure a clean logger state,
    # you can remove handlers here. For simple cases, adding a logger in setup
    # is often sufficient as unit test runners typically isolate output.
    discard # To suppress unused result warning

  test "chat method sends correct request and handles successful response":
    # Configure mock response for a successful API call
    mockHttpResponse = Response(
      status: "200 OK", # Use status: string instead of code: HttpCode
      bodyStream: newStringStream("""{"choices": [{"message": {"content": "Paris, in the realm of testing!"}}]}""")
    )

    # Initialize the provider with our custom mock POST request handler
    let provider = newOpenAIProvider(defaultConf, mockPostRequestHandler)

    let result = provider.chat(testMessages, model = some(DefaultOpenAIModel))

    # Assertions on the captured request details
    check capturedUrl == "https://api.openai.com/v1/chat/completions"

    check capturedHeaders["Authorization"] == "Bearer " & defaultConf.key
    check capturedHeaders["Content-Type"] == "application/json"

    let requestJson = parseJson(capturedRequestBody) # Use the renamed variable here
    check requestJson["model"].getStr() == DefaultOpenAIModel # Verify default model usage
    check requestJson["messages"][0]["role"].getStr() == "system"
    check requestJson["messages"][0]["content"].getStr() == "You are a test assistant."
    check requestJson["messages"][1]["role"].getStr() == "user"
    check requestJson["messages"][1]["content"].getStr() == "What is the capital of testing?"

    # Assertions on the returned ChatResult
    check result.content == "Paris, in the realm of testing!"
    check result.model == DefaultOpenAIModel

  test "chat method uses specified model if provided in config":
    let customModelConf: ProviderConfig = ProviderConfig(key: "test-key", model: "my-custom-model-v1")
    # Initialize the provider with our custom mock POST request handler
    let customModelProvider = newOpenAIProvider(customModelConf, mockPostRequestHandler)

    mockHttpResponse = Response(
      status: "200 OK", # Use status: string
      bodyStream: newStringStream("""{"choices": [{"message": {"content": "Another mocked response for custom model."}}]}""")
    )

    let result = customModelProvider.chat(testMessages)

    let requestJson = parseJson(capturedRequestBody) # Use the renamed variable here
    check requestJson["model"].getStr() == "my-custom-model-v1" # Verify custom model usage
    check result.model == "my-custom-model-v1"

  test "chat method raises IOError on non-2xx HTTP status code":
    mockHttpResponse = Response(
      status: "401 Unauthorized", # Use status: string
      bodyStream: newStringStream("""{"error": {"message": "Incorrect API key provided: sk-xxxx...."}}""")
    )
    # Initialize the provider with our custom mock POST request handler
    let provider = newOpenAIProvider(defaultConf, mockPostRequestHandler)

    expect IOError:
      discard provider.chat(testMessages, model = some("gpt-4"))

  test "chat method raises ValueError on empty choices array in successful response":
    mockHttpResponse = Response(
      status: "200 OK", # Use status: string
      bodyStream: newStringStream("""{"choices": []}""") # Empty choices array
    )
    # Initialize the provider with our custom mock POST request handler
    let provider = newOpenAIProvider(defaultConf, mockPostRequestHandler)

    expect ValueError:
      discard provider.chat(testMessages, model = some("gpt-4"))