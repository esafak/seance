import common
import ../types

import std/[httpclient, logging, options, strutils, streams, json]
import jsony

# --- Internal types for Gemini API ---
type
  GeminiContentPart = object
    text: string

  GeminiContent = object
    role: string # "user" or "model"
    parts: seq[GeminiContentPart]

  GenerationConfig = object
    response_mime_type: string

  GeminiCandidate = object
    content: GeminiContent

  GeminiChatResponse = object
    candidates: seq[GeminiCandidate]

const
  ApiUrlBase = "https://generativelanguage.googleapis.com/v1beta/models/"

type
  GeminiProvider* = ref object of ChatProvider

proc toGeminiContents(messages: seq[ChatMessage]): seq[GeminiContent] =
  for msg in messages:
    let role = if msg.role == assistant: "model" else: "user"
    result.add(GeminiContent(role: role, parts: @[GeminiContentPart(text: msg.content)]))

method chat*(provider: GeminiProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false): ChatResult =
  ## Implementation of the chat method for Gemini.
  let usedModel = provider.getFinalModel(model)
  let apiUrl = ApiUrlBase & usedModel & ":generateContent?key=" & provider.conf.key
  let requestHeaders = newHttpHeaders([("Content-Type", "application/json")])

  var requestBody: string
  if jsonMode:
    var generationConfig = newJObject()
    generationConfig["response_mime_type"] = %"application/json"
    let request = ChatRequest(
      messages: messages,
      generationConfig: generationConfig
    )
    requestBody = request.toJson()
  else:
    let request = ChatRequest(
      messages: messages
    )
    requestBody = request.toJson()

  debug "Gemini Request Body: " & requestBody

  let response = provider.postRequestHandler(apiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "Gemini Response Status: " & $response.status
  debug "Gemini Response Body: " & responseBodyContent

  if response.status.split(' ')[0].parseInt() notin 200..299:
    let errorMessage = "Gemini API Error " & response.status & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = responseBodyContent.fromJson(GeminiChatResponse)
  let content = try: apiResponse.candidates[0].content.parts[0].text
  except IndexDefect:
    let errorMessage = "Gemini response was invalid."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
