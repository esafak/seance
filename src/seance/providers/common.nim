import ../types

import std/httpclient
import std/options

method chat*(provider: ChatProvider, messages: seq[ChatMessage], model: Option[string]): ChatResult {.base.} =
  raise newException(Defect, "chat() not implemented for this provider")

proc defaultHttpPostHandler*(url: string, body: string, headers: HttpHeaders): Response =
  let client = newHttpClient()
  defer: client.close()
  client.headers = headers
  result = client.post(url, body = body)

proc getFinalModel*(provider: ChatProvider, model: Option[string] = none(string)): string =
  ## Determines the final model to be used, respecting overrides and defaults.
  if model.isSome():
    return model.get()

  let confModel = provider.conf.model
  if confModel.len > 0:
    return confModel

  return provider.defaultModel

proc `$`*(role: MessageRole): string =
  case role:
  of system: "system"
  of user: "user"
  of assistant: "assistant"
