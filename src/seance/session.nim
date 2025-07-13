import std/json
import std/os
import providers/common

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
