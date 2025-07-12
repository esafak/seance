import std/json
import std/os
import providers
from providers/common import Session

const sessionDir = getHomeDir() / ".config" / "seance" / "sessions"

proc getSessionFilePath(sessionId: string): string =
  createDir(sessionDir)
  return sessionDir / sessionId & ".json"

proc loadSession*(sessionId: string): Session =
  let sessionFile = getSessionFilePath(sessionId)
  if not fileExists(sessionFile):
    return Session(provider: "", messages: @[])

  let data = parseFile(sessionFile)
  return to(data, Session)

proc saveSession*(sessionId: string, session: Session) =
  let sessionFile = getSessionFilePath(sessionId)
  let data = %session
  writeFile(sessionFile, pretty(data))
