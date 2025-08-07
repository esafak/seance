import ../types

import std/httpclient
import std/options
import std/json

method chat*(provider: ChatProvider, messages: seq[ChatMessage], model: Option[string], jsonMode: bool, schema: Option[JsonNode]): ChatResult {.base.} =
  raise newException(Defect, "chat() not implemented for this provider")

proc defaultHttpPostHandler*(url: string, body: string, headers: HttpHeaders): Response =
  let client = newHttpClient()
  defer: client.close()
  client.headers = headers
  result = client.post(url, body = body)

proc defaultHttpGetHandler*(url: string): Response =
  let client = newHttpClient()
  defer: client.close()
  result = client.get(url)

proc getFinalModel*(provider: ChatProvider, model: Option[string] = none(string)): string =
  ## Determines the final model to be used, respecting overrides and defaults.
  return model.get(provider.conf.model.get(provider.defaultModel))

proc `$`*(role: MessageRole): string =
  case role:
  of MessageRole.system: "system"
  of MessageRole.user: "user"
  of MessageRole.assistant: "assistant"
