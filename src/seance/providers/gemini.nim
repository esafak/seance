import common
import ../defaults
import ../types

import std/[httpclient, logging, options, strutils, streams]
import jsony

# --- Internal types for Gemini API ---
type
  GeminiContentPart = object
    text: string

  GeminiContent = object
    role: string # "user" or "model"
    parts: seq[GeminiContentPart]

  GeminiChatRequest = object
    contents: seq[GeminiContent]

  GeminiCandidate = object
    content: GeminiContent

  GeminiChatResponse = object
    candidates: seq[GeminiCandidate]

const
  ApiUrlBase = "https://generativelanguage.googleapis.com/v1beta/models/"

type
  GeminiProvider* = ref object of ChatProvider

proc newGeminiProvider*(conf: ProviderConfig, postRequestHandler: HttpPostHandler = defaultHttpPostHandler): GeminiProvider =
  ## Creates a new instance of the Gemini provider.
  return GeminiProvider(conf: conf, postRequestHandler: postRequestHandler, defaultModel: DefaultGeminiModel)

proc toGeminiContents(messages: seq[ChatMessage]): seq[GeminiContent] =
  for msg in messages:
    let role = if msg.role == assistant: "model" else: "user"
    result.add(GeminiContent(role: role, parts: @[GeminiContentPart(text: msg.content)]))

method chat*(provider: GeminiProvider, messages: seq[ChatMessage], model: Option[string] = none(string)): ChatResult =
  ## Implementation of the chat method for Gemini.
  let usedModel = provider.getFinalModel(model)
  let apiUrl = ApiUrlBase & usedModel & ":generateContent?key=" & provider.conf.key
  let requestHeaders = newHttpHeaders([("Content-Type", "application/json")])
  let requestBody = GeminiChatRequest(
    contents: toGeminiContents(messages)
  ).toJson()

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
