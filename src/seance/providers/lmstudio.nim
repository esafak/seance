import ../defaults
import ../types
import common

import std/[httpclient, json, logging, options, streams]

# --- Internal types for LMStudio API ---
type
  LMStudioChatRequest* = object
    model*: string
    messages*: seq[ChatMessage]

  LMStudioProvider* = ref object of ChatProvider

proc fromLMStudio*(node: JsonNode): ChatResponse =
  var choices: seq[ChatChoice] = @[]
  if node.hasKey("choices"):
    for choiceNode in to(node["choices"], seq[JsonNode]):
      if choiceNode.hasKey("message"):
        let messageNode = choiceNode["message"]
        var role: MessageRole
        if messageNode.hasKey("role"):
          let roleStr = messageNode["role"].getStr()
          case roleStr
          of "system": role = system
          of "user": role = user
          of "assistant": role = assistant
          else: role = system # Default to system if unknown
        else: role = system # Default to system if role key is missing
        let content = if messageNode.hasKey("content"):
          messageNode["content"].getStr()
        else: ""
        choices.add(ChatChoice(message: ChatMessage(role: role, content: content)))
  result = ChatResponse(choices: choices)

# --- Provider Implementation ---

method chat*(provider: LMStudioProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for LMStudio using a live API call
  let usedModel = provider.getFinalModel(model)
  var requestHeaders = newHttpHeaders([
    ("Content-Type", "application/json")
  ])

  if provider.conf.key.len > 0:
    requestHeaders.add("Authorization", "Bearer " & provider.conf.key)

  var processedMessages = messages
  if jsonMode:
    # LMStudio requires the word "json" in the prompt to use response_format
    # Append a system message to ensure this requirement is met
    processedMessages.add(ChatMessage(role: system, content: "Return the response in JSON format."))

  var requestBody: string
  if jsonMode:
    let schemaNode = schema.get(%*{"type": "object"})
    let request = LMStudioChatRequest(model: usedModel, messages: processedMessages)
    var requestJson = %*request
    requestJson["response_format"] = %*{"type": "json_object"}
    requestBody = $requestJson
  else:
    let request = LMStudioChatRequest(model: usedModel, messages: processedMessages)
    requestBody = $(%*request)

  let endpoint = provider.conf.endpoint.get(DefaultLMStudioEndpoint)

  info "LMStudio Request Body: " & requestBody
  debug "curl -X POST " & endpoint & " -H \"Content-Type: application/json\" -d '" & requestBody & "'"

  let response = provider.postRequestHandler(endpoint, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "LMStudio Response Status: " & $response.code
  debug "LMStudio Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "LMStudio API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = fromLMStudio(parseJson(responseBodyContent))
  if apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len > 0:
    let content = apiResponse.choices[0].message.content
    return ChatResult(content: content, model: usedModel)
  elif apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len == 0:
    let refusal = "empty content"
    return ChatResult(content: "AI Refusal: " & refusal, model: usedModel)
  else:
    let errorMessage = "LMStudio response contained no choices or refusal."
    error errorMessage
    raise newException(ValueError, errorMessage)
