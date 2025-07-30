import unittest
import std/json
import std/httpclient
import std/options
import std/logging
import std/streams

import seance/providers
import seance/types

var mockHttpResponse: Response
var capturedUrl: string
var capturedRequestBody: string
var capturedHeaders: HttpHeaders

proc mockPostRequestHandler(url: string, requestBodyStr: string, headers: HttpHeaders): Response =
  capturedUrl = url
  capturedRequestBody = requestBodyStr
  capturedHeaders = headers
  return mockHttpResponse

suite "Anthropic Provider":
  let defaultConf: ProviderConfig = ProviderConfig(key: "test-key-anthropic", model: none(string))
  let testMessages = @[
    ChatMessage(role: system, content: "You are a test assistant for Anthropic."),
    ChatMessage(role: user, content: "What is the capital of testing?")
  ]

  setup:
    mockHttpResponse = Response()
    capturedUrl = ""
    capturedRequestBody = ""
    capturedHeaders = newHttpHeaders()
    addHandler(newConsoleLogger(levelThreshold = lvlInfo))

  test "chat method sends correct request and handles successful response":
    let mockModel = "claude-3-opus-20240229"
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream("""{"content": [{"type": "text", "text": "Test City, in the realm of Anthropic testing!"}], "model": """" & mockModel & """"}""")
    )

    let provider = newProvider(some(Anthropic), some(defaultConf))
    provider.postRequestHandler = mockPostRequestHandler
    let result = provider.chat(testMessages, some(mockModel), false, none(JsonNode))

    check capturedUrl == "https://api.anthropic.com/v1/messages"
    check capturedHeaders["x-api-key"] == defaultConf.key
    check capturedHeaders["Content-Type"] == "application/json"
    check capturedHeaders["anthropic-version"] == "2023-06-01"

    let requestJson = parseJson(capturedRequestBody)
    check requestJson["model"].getStr() == mockModel
    check requestJson["messages"][0]["role"].getStr() == "system"
    check requestJson["messages"][1]["role"].getStr() == "user"

    check result.content == "Test City, in the realm of Anthropic testing!"
    check result.model == mockModel