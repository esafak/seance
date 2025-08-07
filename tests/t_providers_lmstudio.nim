import seance/types
import seance/defaults
import seance/providers
import seance/config

import std/[json, tables, options, streams, httpclient, logging, unittest, os, strutils]

# --- Manual Mocking Setup for HTTP POST Request ---
var mockHttpResponse: Response
var capturedUrl: string
var capturedRequestBody: string
var capturedHeaders: HttpHeaders

var mockModelsResponse: Response

proc mockPostRequestHandler(url: string, requestBodyStr: string, headers: HttpHeaders): Response =
  debug "--- Inside mockPostRequestHandler ---"
  debug "Received Headers in mock: " & $headers
  capturedUrl = url
  capturedRequestBody = requestBodyStr
  capturedHeaders = headers
  return mockHttpResponse

proc mockGetRequestHandler(url: string): Response =
  debug "--- Inside mockGetRequestHandler ---"
  debug "Received URL in mock: " & url
  if "models" in url:
    return mockModelsResponse
  else:
    return Response(status: "404 Not Found", bodyStream: newStringStream(""))

# --- Test Suites ---

suite "LMStudio Provider":
  let testMessages = @[
    ChatMessage(role: system, content: "You are a test assistant."),
    ChatMessage(role: user, content: "What is the capital of testing?")
  ]

  setup:
    mockHttpResponse = Response()
    capturedUrl = ""
    capturedRequestBody = ""
    capturedHeaders = newHttpHeaders()
    addHandler(newConsoleLogger(levelThreshold = lvlInfo))

  teardown:
    discard

  test "chat method sends correct request without auth header":
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"choices": [{"message": {"role": "assistant", "content": "Local response!"}}]}""")
    )

    let conf = ProviderConfig(key: "", model: none(string), endpoint: none(string))
    let provider = newProvider(some(LMStudio), some(conf))
    provider.postRequestHandler = mockPostRequestHandler

    let result = provider.chat(testMessages, model = none(string), jsonMode = false, schema = none(JsonNode))

    check capturedUrl == DefaultLMStudioEndpoint
    check not capturedHeaders.hasKey("Authorization")
    check capturedHeaders["Content-Type"] == "application/json"

    let requestJson = parseJson(capturedRequestBody)
    check requestJson["model"].getStr() == DefaultModels[LMStudio]
    check result.content == "Local response!"

  test "chat method sends auth header when key is provided":
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"choices": [{"message": {"role": "assistant", "content": "Local response with key!"}}]}""")
    )

    let conf = ProviderConfig(key: "test-key", model: none(string), endpoint: none(string))
    let provider = newProvider(some(LMStudio), some(conf))
    provider.postRequestHandler = mockPostRequestHandler

    discard provider.chat(testMessages, model = none(string), jsonMode = false, schema = none(JsonNode))

    check capturedHeaders.hasKey("Authorization")
    check capturedHeaders["Authorization"] == "Bearer test-key"

  test "chat method uses custom endpoint from config":
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"choices": [{"message": {"role": "assistant", "content": "Custom endpoint response!"}}]}""")
    )

    let customEndpoint = "http://localhost:8080/v1/chat/completions"
    let conf = ProviderConfig(key: "", model: none(string), endpoint: some(customEndpoint))
    let provider = newProvider(some(LMStudio), some(conf))
    provider.postRequestHandler = mockPostRequestHandler

    discard provider.chat(testMessages, model = none(string), jsonMode = false, schema = none(JsonNode))

    check capturedUrl == customEndpoint

  test "chat method raises IOError with parsed message on non-2xx HTTP status code":
    let errorMessage = "Failed to load model"
    mockHttpResponse = Response(
      status: "404 Not Found",
      bodyStream: newStringStream("""{"error": {"message": "$1"}}""" % errorMessage)
    )
    let conf = ProviderConfig(key: "", model: none(string), endpoint: none(string))
    let provider = newProvider(some(LMStudio), some(conf))
    provider.postRequestHandler = mockPostRequestHandler

    try:
      discard provider.chat(testMessages, model = none(string), jsonMode = false, schema = none(JsonNode))
      fail()
    except IOError as e:
      check e.msg.contains(errorMessage)

  test "chat method raises ValueError on empty choices array":
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"choices": []}""")
    )
    let conf = ProviderConfig(key: "", model: none(string), endpoint: none(string))
    let provider = newProvider(some(LMStudio), some(conf))
    provider.postRequestHandler = mockPostRequestHandler

    expect ValueError:
      discard provider.chat(testMessages, model = none(string), jsonMode = false, schema = none(JsonNode))

  test "newProvider uses default config when lmstudio is not in config file":
    # Create a temporary config file without an [lmstudio] section
    let tempConfPath = "temp_test_config.ini"
    writeFile(tempConfPath, "[seance]\ndefault_provider = lmstudio")
    setConfigPath(tempConfPath)

    # Initialize the provider without a specific config
    let provider = newProvider(some(LMStudio))

    # Assert that the provider was created with the default settings
    check provider.defaultModel == DefaultModels[LMStudio]
    check provider.conf.key == ""
    check provider.conf.model.isNone()
    check provider.conf.endpoint.isNone()

    # Clean up the temporary file
    removeFile(tempConfPath)
    setConfigPath("") # Reset config path

  test "chat method proceeds when model is not loaded in non-interactive mode":
    # Mock the models endpoint to return a list of available models
    mockModelsResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"data": [{"id": "model-1", "state": "loaded"}, {"id": "model-2", "state": "not-loaded"}]}""")
    )
    # Mock the chat completions endpoint
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"choices": [{"message": {"role": "assistant", "content": "Fallback response!"}}], "model": "model-2"}""")
    )

    let conf = ProviderConfig(key: "", model: some("model-2"), endpoint: none(string))
    let provider = newProvider(some(LMStudio), some(conf))
    provider.postRequestHandler = mockPostRequestHandler
    provider.getRequestHandler = mockGetRequestHandler

    # In a non-interactive session, it should just proceed
    let result = provider.chat(testMessages, model = none(string), jsonMode = false, schema = none(JsonNode))

    let requestJson = parseJson(capturedRequestBody)
    check requestJson["model"].getStr() == "model-2"
    check result.model == "model-2"
