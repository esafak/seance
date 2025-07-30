import common
import ../types

import std/[httpclient, logging, options, strutils, streams, json]

# --- Internal types for Gemini API ---
type
  GeminiContentPart = object
    text: string

  GeminiContent = object
    role: string # "user" or "model"
    parts: seq[GeminiContentPart]

  GeminiCandidate = object
    content: GeminiContent

  GeminiChatResponse = object
    candidates: seq[GeminiCandidate]

  GeminiChatRequest* = object
    contents*: seq[GeminiContent]
    generationConfig*: JsonNode

const
  ApiUrlBase = "https://generativelanguage.googleapis.com/v1beta/models/"

type
  GeminiProvider* = ref object of ChatProvider

proc fromGemini*(node: JsonNode): ChatResponse =
  var candidates: seq[JsonNode] = @[]
  if node.hasKey("candidates"):
    candidates = to(node["candidates"], seq[JsonNode])
  var choices: seq[ChatChoice] = @[]
  for candidate in candidates:
    let content = candidate["content"]["parts"][0]["text"].getStr()
    choices.add(ChatChoice(message: ChatMessage(role: assistant, content: content)))
  result = ChatResponse(choices: choices)

proc toGeminiContents(messages: seq[ChatMessage]): seq[GeminiContent] =
  for msg in messages:
    let role = if msg.role == assistant: "model" else: "user"
    result.add(GeminiContent(role: role, parts: @[GeminiContentPart(text: msg.content)]))

method chat*(provider: GeminiProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for Gemini.
  let usedModel = provider.getFinalModel(model)
  let apiUrl = ApiUrlBase & usedModel & ":generateContent?key=" & provider.conf.key
  let requestHeaders = newHttpHeaders([("Content-Type", "application/json")])

  var requestBody: string
  if jsonMode:
    var generationConfig = newJObject()
    generationConfig["response_mime_type"] = %"application/json"
    if schema.isSome:
      generationConfig["response_schema"] = schema.get

    let request = GeminiChatRequest(
      contents: toGeminiContents(messages),
      generationConfig: generationConfig
    )
    requestBody = $(%*request)
  else:
    let request = GeminiChatRequest(
      contents: toGeminiContents(messages)
    )
    var jsonRequest = %*request
    jsonRequest.delete("generationConfig")
    requestBody = $jsonRequest

  debug "Gemini Request Body: " & requestBody

  let response = provider.postRequestHandler(apiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "Gemini Response Status: " & $response.status
  debug "Gemini Response Body: " & responseBodyContent

  if response.status.split(' ')[0].parseInt() notin 200..299:
    let errorMessage = "Gemini API Error " & response.status & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = fromGemini(parseJson(responseBodyContent))
  let content = try: apiResponse.choices[0].message.content
  except IndexDefect:
    let errorMessage = "Gemini response was invalid."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
