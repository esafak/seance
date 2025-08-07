import common
import ../types

import std/[httpclient, logging, options, streams, json]

# --- Internal types for OpenAI API ---
type
  OpenAIChatRequest* = object
    model*: string
    messages*: seq[ChatMessage]

  OpenAIProvider* = ref object of ChatProvider

proc fromOpenAI*(node: JsonNode): ChatResponse =
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

const ApiUrl = "https://api.openai.com/v1/chat/completions"

# --- Provider Implementation ---

method chat*(provider: OpenAIProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for OpenAI using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json")
  ])

  var processedMessages = messages
  if jsonMode:
    # OpenAI requires the word "json" in the prompt to use response_format
    # Append a system message to ensure this requirement is met
    processedMessages.add(ChatMessage(role: system, content: "Return the response in JSON format."))

  var requestBody: string
  if jsonMode:
    let schemaNode = schema.get(%*{"type": "object"})
    let request = OpenAIChatRequest(model: usedModel, messages: processedMessages)
    var requestJson = %*request
    requestJson["response_format"] = %*{"type": "json_object"}
    requestBody = $requestJson
  else:
    let request = OpenAIChatRequest(model: usedModel, messages: processedMessages)
    requestBody = $(%*request)

  info "OpenAI Request Body: " & requestBody
  debug "curl -X POST " & ApiUrl & " -H \"Authorization: Bearer " & provider.conf.key & "\" -H \"Content-Type: application/json\" -d '" & requestBody & "'"

  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenAI Response Status: " & $response.code
  debug "OpenAI Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    var errorMessage = "OpenAI API Error " & $response.code
    try:
      let errorJson = parseJson(responseBodyContent)
      if errorJson.hasKey("error") and errorJson["error"].hasKey("message"):
        errorMessage &= ": " & errorJson["error"]["message"].getStr()
      else:
        errorMessage &= ": " & responseBodyContent
    except JsonParsingError:
      errorMessage &= ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = fromOpenAI(parseJson(responseBodyContent))
  if apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len > 0:
    let content = apiResponse.choices[0].message.content
    let model = if apiResponse.model.len > 0: apiResponse.model else: usedModel
    if model != usedModel:
      info "Model fallback: " & usedModel & " was requested, but " & model & " was used."
    return ChatResult(content: content, model: model)
  elif apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len == 0:
    let refusal = "empty content"
    return ChatResult(content: "AI Refusal: " & refusal, model: usedModel)
  else:
    let errorMessage = "OpenAI response contained no choices or refusal."
    error errorMessage
    raise newException(ValueError, errorMessage)
