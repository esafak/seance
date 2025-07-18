import providers
import providers/common

import std/json
import std/options
import std/os

type
  Session* = object
    messages*: seq[ChatMessage]

var sessionDir* = getHomeDir() / ".config" / "seance" / "sessions"

proc getSessionFilePath*(sessionId: string): string =
  createDir(sessionDir)
  return sessionDir / sessionId & ".json"

proc loadSession*(sessionId: string): Session =
  let sessionFile = getSessionFilePath(sessionId)
  if not fileExists(sessionFile):
    return Session(messages: @[])

  let data = parseFile(sessionFile)
  var sessionObj = to(data, Session)

  # Handle old session format where 'provider' was at the top level
  if data.hasKey("provider"):
    # Iterate through messages and assign the provider as model to assistant messages
    for i in 0..<sessionObj.messages.len:
      if sessionObj.messages[i].role == assistant:
        sessionObj.messages[i].model = data["provider"].getStr()

  return sessionObj

proc saveSession*(sessionId: string, session: Session) =
  let sessionFile = getSessionFilePath(sessionId)
  let data = %session
  writeFile(sessionFile, pretty(data))

proc newChatSession*(): Session =
  return Session(messages: @[])

# This proc uses ChatProvider rather than Provider so we can mock it in tests
proc chat*(session: var Session, query: string, provider: ChatProvider, model: Option[string] = none(string)): ChatResult =
  session.messages.add(ChatMessage(role: user, content: query))
  let usedModel = provider.getFinalModel(model)
  result = provider.chat(session.messages, some(usedModel))
  session.messages.add(ChatMessage(role: assistant, content: result.content, model: result.model))
  return result
