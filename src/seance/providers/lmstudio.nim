import ../defaults
import ../types
import common

import std/[httpclient, json, logging, options, sequtils, streams, strutils, terminal]

# --- Internal types for LMStudio API ---
type
  LMStudioModel* = object
    id*: string
    state*: string

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
  var usedModel = provider.getFinalModel(model)
  let endpoint = provider.conf.endpoint.get(DefaultLMStudioEndpoint)
  let modelsUrl = endpoint.replace("/chat/completions", "/models")

  try:
    let modelsResponse = provider.getRequestHandler(modelsUrl)
    let modelsBody = modelsResponse.body
    let modelsJson = parseJson(modelsBody)
    let availableModels = to(modelsJson, LMStudioModelsResponse)
    var requestedModel: Option[LMStudioModel] = none(LMStudioModel)
    for m in availableModels.data:
      if m.id == usedModel:
        requestedModel = some(m)
        break

    if requestedModel.isSome and requestedModel.get().state != "loaded":
      let loadedModels = availableModels.data.filter(proc(m: LMStudioModel): bool = m.state == "loaded")
      if isatty(stdin):
        echo "The model '", usedModel, "' is not currently loaded."
        if loadedModels.len > 0:
          echo "Loaded models are: ", loadedModels.map(proc(m: LMStudioModel): string = m.id).join(", ")
          stdout.write "Would you like to load '", usedModel, "' or use a loaded model? (load/use) "
          let choice = stdin.readLine().strip().toLowerAscii()
          if choice == "use":
            if loadedModels.len == 1:
              usedModel = loadedModels[0].id
            else:
              stdout.write "Please specify which loaded model to use: "
              usedModel = stdin.readLine().strip()
        else:
          stdout.write "Would you like to load '", usedModel, "'? (y/N) "
          let choice = stdin.readLine().strip().toLowerAscii()
          if choice != "y":
            quit(0)
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
      info "Model fallback: " & usedModel & " was requested, but " & model & " was used. This can happen if the requested model is not loaded in LMStudio."
    return ChatResult(content: content, model: model)
  elif apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len == 0:
    let refusal = "empty content"
    return ChatResult(content: "AI Refusal: " & refusal, model: usedModel)
  else:
    let errorMessage = "LMStudio response contained no choices or refusal."
    error errorMessage
    raise newException(ValueError, errorMessage)
