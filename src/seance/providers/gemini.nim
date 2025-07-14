import ../config
import common

import std/[httpclient, strutils, streams]
import std/logging

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
    conf*: ProviderConfig
    postRequestHandler: proc(url: string, body: string, headers: HttpHeaders): Response

proc defaultHttpPostHandler(url: string, body: string, headers: HttpHeaders): Response =
  let client = newHttpClient()
  defer: client.close()
  client.headers = headers
  result = client.post(url, body = body)

proc newGeminiProvider*(conf: ProviderConfig, postRequestHandler: proc(
    url: string, body: string, headers: HttpHeaders): Response = nil): GeminiProvider =
  ## Creates a new instance of the Gemini provider.
  let handler = if postRequestHandler == nil:
                  defaultHttpPostHandler
                else:
                  postRequestHandler
  return GeminiProvider(conf: conf, postRequestHandler: handler)

proc toGeminiContents(messages: seq[ChatMessage]): seq[GeminiContent] =
  for msg in messages:
    let role = if msg.role == assistant: "model" else: "user"
    result.add(GeminiContent(role: role, parts: @[GeminiContentPart(text: msg.content)]))

method chat*(provider: GeminiProvider, messages: seq[ChatMessage], model: string = ""): ChatResult =
  ## Implementation of the chat method for Gemini.
  let modelToUse = if model.len > 0: model else: provider.conf.model
  if modelToUse.len == 0:
    raise newException(ValueError, "Model not specified via argument or config")

  let apiUrl = ApiUrlBase & modelToUse & ":generateContent?key=" & provider.conf.key

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
  if apiResponse.candidates.len == 0 or apiResponse.candidates[0].content.parts.len == 0:
    let errorMessage = "Gemini response contained no candidates or content parts."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(
    content: apiResponse.candidates[0].content.parts[0].text,
    model: model)
