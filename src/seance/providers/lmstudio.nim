import ../defaults
import ../types
import common

import std/[httpclient, json, logging, options, sequtils, streams, strutils]

# --- Internal types for LMStudio API ---
type
  LMStudioModel* = object
    id*: string

  LMStudioModelsResponse* = object
    data*: seq[LMStudioModel]

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
  let model = if node.hasKey("model"): node["model"].getStr() else: ""
  result = ChatResponse(choices: choices, model: model)

# --- Provider Implementation ---

method chat*(provider: LMStudioProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for LMStudio using a live API call
  let usedModel = provider.getFinalModel(model)
  let endpoint = provider.conf.endpoint.get(DefaultLMStudioEndpoint)
  let modelsUrl = endpoint.replace("/chat/completions", "/models")

  try:
    let modelsResponse = provider.getRequestHandler(modelsUrl)
    let modelsBody = modelsResponse.body
    let modelsJson = parseJson(modelsBody)
    let availableModels = to(modelsJson, LMStudioModelsResponse)
    let availableModelIds = availableModels.data.map(proc(m: LMStudioModel): string = m.id)
    if usedModel notin availableModelIds:
      warn "Model '" & usedModel & "' not found in LMStudio. LMStudio may fall back to another model."
      if availableModelIds.len > 0:
        info "Available models: " & availableModelIds.join(", ")
  except Exception as e:
    warn "Could not fetch models from LMStudio: " & e.msg

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
    let model = if apiResponse.model.len > 0: apiResponse.model else: usedModel
    if model != usedModel:
      info "Model changed from " & usedModel & " to " & model
    return ChatResult(content: content, model: model)
  elif apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len == 0:
    let refusal = "empty content"
    return ChatResult(content: "AI Refusal: " & refusal, model: usedModel)
  else:
    let errorMessage = "LMStudio response contained no choices or refusal."
    error errorMessage
    raise newException(ValueError, errorMessage)
