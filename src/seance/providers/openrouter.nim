import common
import ../types

import std/[httpclient, logging, options, streams, json]

# --- Internal types for OpenRouter API ---
type
  OpenRouterProvider* = ref object of ChatProvider

proc fromOpenRouter*(node: JsonNode): ChatResponse =
  var choices: seq[ChatChoice] = @[]
  if not node.isNil and node.hasKey("choices"):
    for choiceNode in to(node["choices"], seq[JsonNode]):
      if not choiceNode.isNil and choiceNode.hasKey("message"):
        let messageNode = choiceNode["message"]
        var role: MessageRole
        if not messageNode.isNil and messageNode.hasKey("role"):
          let roleStr = messageNode["role"].getStr()
          case roleStr
          of "system": role = system
          of "user": role = user
          of "assistant": role = assistant
          else: role = system # Default to system if unknown
        else: role = system # Default to system if role key is missing
        let content = if not messageNode.isNil and messageNode.hasKey("content"):
          messageNode["content"].getStr()
        else: ""
        choices.add(ChatChoice(message: ChatMessage(role: role, content: content)))
  result = ChatResponse(choices: choices)

const
  ApiUrl = "https://openrouter.ai/api/v1/chat/completions"
  Referer = "https://github.com/dmadisetti/seance"
  Title = "Seance"

# --- Provider Implementation ---

method chat*(provider: OpenRouterProvider, messages: seq[ChatMessage], model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  ## Implementation of the chat method for OpenRouter using a live API call
  let usedModel = provider.getFinalModel(model)
  let requestHeaders = newHttpHeaders([
    ("Authorization", "Bearer " & provider.conf.key),
    ("Content-Type", "application/json"),
    ("HTTP-Referer", Referer),
    ("X-Title", Title)
  ])

  var requestBody: string
  debug "Constructing OpenRouter request body..."

  # Explicitly convert messages to a JsonNode array
  var messagesJsonArray = newJArray()
  for msg in messages:
    messagesJsonArray.add(%*{"role": $(msg.role), "content": msg.content})

  if jsonMode:
    var requestJson = newJObject()
    requestJson["model"] = %usedModel
    requestJson["messages"] = messagesJsonArray

    var responseFormatNode = newJObject()
    if schema.isSome:
      responseFormatNode["type"] = %"json_schema"
      debug "Schema option is Some."
      var finalSchemaNode: JsonNode
      if schema.get.isNil:
        error "Schema.get returned nil JsonNode. This should not happen."
        raise newException(ValueError, "Schema content is nil.")
      else:
        debug "Schema.get is not nil. Converting to string and parsing back to force clean copy."
        finalSchemaNode = parseJson($(schema.get))
        debug "Successfully parsed schema string back to JsonNode."

      responseFormatNode["json_schema"] = %*{
        "name": "generated_schema",
        "strict": true,
        "schema": finalSchemaNode
      }
      debug "Constructed json_schema object: " & $(responseFormatNode["json_schema"])
    else:
      responseFormatNode["type"] = %"json_object"

    requestJson["response_format"] = responseFormatNode
    requestBody = $requestJson
  else:
    var requestJson = newJObject()
    requestJson["model"] = %usedModel
    requestJson["messages"] = messagesJsonArray
    requestBody = $requestJson

  debug "OpenRouter Request Body constructed: " & requestBody
  debug "Calling postRequestHandler..."
  let response = provider.postRequestHandler(ApiUrl, requestBody, requestHeaders)
  debug "postRequestHandler returned."
  let responseBodyContent = streams.readAll(response.bodyStream)

  debug "OpenRouter Response Status: " & $response.code
  debug "OpenRouter Response Body: " & responseBodyContent

  if response.code notin {Http200, Http201}:
    let errorMessage = "OpenRouter API Error " & $response.code & ": " & responseBodyContent
    error errorMessage
    raise newException(IOError, errorMessage)

  let apiResponse = fromOpenRouter(parseJson(responseBodyContent))
  let content = if apiResponse.choices.len > 0 and apiResponse.choices[0].message.content.len > 0:
    apiResponse.choices[0].message.content
  else:
    let errorMessage = "OpenRouter response contained no choices or message content."
    error errorMessage
    raise newException(ValueError, errorMessage)

  return ChatResult(content: content, model: usedModel)
