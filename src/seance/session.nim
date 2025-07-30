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

  return to(data, Session)

proc saveSession*(sessionId: string, session: Session) =
  let sessionFile = getSessionFilePath(sessionId)
  let data = %session
  writeFile(sessionFile, pretty(data))

proc newChatSession*(): Session =
  return Session(messages: @[])

# This proc uses ChatProvider rather than Provider so we can mock it in tests
proc chat*(session: var Session, query: string, provider: ChatProvider, model: Option[string] = none(string), jsonMode: bool = false, schema: Option[JsonNode] = none(JsonNode)): ChatResult =
  session.messages.add(ChatMessage(role: user, content: query))
  let usedModel = provider.getFinalModel(model)
  result = provider.chat(session.messages, some(usedModel), jsonMode, schema)
  session.messages.add(ChatMessage(role: assistant, content: result.content))
  return result
