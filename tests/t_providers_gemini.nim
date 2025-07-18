import unittest
import std/[httpclient, json, options, streams, logging, tables]

import seance/defaults
import seance/types
import seance/providers/gemini

var mockHttpResponse: Response
var capturedUrl: string
var capturedRequestBody: string
var capturedHeaders: HttpHeaders

proc mockPostRequestHandler(url: string, requestBodyStr: string, headers: HttpHeaders): Response =
  capturedUrl = url
  capturedRequestBody = requestBodyStr
  capturedHeaders = headers
  return mockHttpResponse

suite "Gemini Provider":
  let defaultConf: ProviderConfig = ProviderConfig(key: "test-key-gemini", model: "")
  let testMessages = @[
    ChatMessage(role: system, content: "You are a test assistant for Gemini."),
    ChatMessage(role: user, content: "What is the capital of testing?")
  ]

  setup:
    mockHttpResponse = Response()
    capturedUrl = ""
    capturedRequestBody = ""
    capturedHeaders = newHttpHeaders()
    addHandler(newConsoleLogger(levelThreshold = lvlInfo))

  test "chat method sends correct request and handles successful response":
    let responseJson = """
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "Gem City, in the realm of Gemini testing!"
          }
        ],
        "role": "model"
      }
    }
  ]
}
"""
    mockHttpResponse = Response(
      status: "200 OK",
      bodyStream: newStringStream(responseJson)
    )

    const DefaultGeminiModel = DefaultModels[Gemini]
    let provider = newGeminiProvider(defaultConf, mockPostRequestHandler)
    let result = provider.chat(testMessages, model = some(DefaultGeminiModel))

    let expectedUrl = "https://generativelanguage.googleapis.com/v1beta/models/" & DefaultGeminiModel & ":generateContent?key=" & defaultConf.key
    check capturedUrl == expectedUrl
    check capturedHeaders["Content-Type"] == "application/json"

    let requestJson = parseJson(capturedRequestBody)
    check requestJson["contents"][0]["role"].getStr() == "user"
    check requestJson["contents"][0]["parts"][0]["text"].getStr() == "You are a test assistant for Gemini."
    check requestJson["contents"][1]["role"].getStr() == "user"

    check result.content == "Gem City, in the realm of Gemini testing!"
    check result.model == DefaultGeminiModel
