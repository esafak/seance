import config
import providers
import session
import times
import types
import uuid

import std/algorithm
import std/logging
import std/options
import std/os
import std/strutils
import std/terminal

proc chat*(
  prompt: seq[string],
  provider: Option[Provider] = none(Provider),
  model: Option[string] = none(string),
  systemPrompt: Option[string] = none(string),
  session: Option[string] = none(string),
  verbose: int = 0,
  dryRun: bool = false,
  noSession: bool = false
) =
  ## Sends a single chat prompt to the specified provider and prints the response.
  let stdinContent = if not isatty(stdin) : some(stdin.readAll()) else : none(string)

  let finalPrompt: string =
    if prompt.len > 0 and stdinContent.isSome:
      prompt.join(" ") & "\n\n" & stdinContent.get("")
    elif prompt.len > 0:
      prompt.join(" ")
    elif stdinContent.isSome:
      stdinContent.get
    else:
      echo "Error: No prompt provided either as an argument or via stdin."
      quit(1)

  if finalPrompt.len == 0:
    echo "Error: Prompt is empty."
    quit(1)

  if dryRun:
    echo finalPrompt
    quit(0)

  let logLevel = case verbose:
    of 0: lvlInfo
    of 1: lvlDebug
    else: lvlAll

  var logger = newConsoleLogger(levelThreshold = logLevel, useStderr = true)
  addHandler(logger)

  var config: SeanceConfig
  while true:
    try:
      config = loadConfig()
      break
    except ConfigError as e:
      error "Configuration Error: " & e.msg
      let configPath = getConfigPath()
      if "invalid" in e.msg:
        if isatty(stdin):
          stdout.write "Your config file appears to be corrupt. Delete it? (y/N) "
          let response = stdin.readLine().strip().toLowerAscii()
          if response == "y":
            try:
              removeFile(configPath)
              echo "Deleted " & configPath
              continue # Retry loading the config
            except Exception as e:
              error "Failed to delete " & configPath & ": " & e.msg
          else:
            echo "Corrupt config file not deleted."
        else:
          echo "Corrupt config file found but not deleted (not running in interactive terminal)."
      quit(1)

  var sessionId: string
  var sessionObj: Session
  var newSessionCreated = false

  if not noSession and (session.isSome or config.autoSession):
    if session.isSome:
      sessionId = session.get
    else:
      sessionId = $uuidv7()
      newSessionCreated = true
    sessionObj = loadSession(sessionId)
  else:
    sessionObj = Session(messages: @[])

  if systemPrompt.isSome:
    sessionObj.messages.add(ChatMessage(role: system, content: systemPrompt.get)) # No model for system/user messages
  sessionObj.messages.add(ChatMessage(role: user, content: finalPrompt)) # No model for system/user messages

  try:
    let llmProvider: ChatProvider = getProvider(provider, config)
    let modelUsed = model.get(llmProvider.conf.model)
    let result = llmProvider.chat(sessionObj.messages, some(modelUsed))
    info "Using " & modelUsed & "\n"
    echo result.content

    if sessionId.len > 0 and not noSession:
      sessionObj.messages.add(ChatMessage(role: assistant, content: result.content, model: result.model))
      saveSession(sessionId, sessionObj)
      if newSessionCreated:
        stderr.writeLine "\nTo continue this session, call 'seance chat --session=" & sessionId & " ...'"
  except Exception as e:
    error "An error occurred during chat: " & e.msg
    quit(1)

proc formatAge(age: Duration): string =
  if age.inHours < 1:
    result = $age.inMinutes & "m"
  elif age.inDays < 1:
    result = $age.inHours & "h"
  else:
    result = $age.inDays & "d"

proc list*() =
  ## Lists all available sessions.
  if not dirExists(session.sessionDir):
    echo "No sessions found."
    return

  var corruptFiles: seq[string]
  var sessionData: seq[(string, Duration, string, string, string)] # (sessionId, rawAge, age, model, description)

  var maxSessionIdLen = "Session ID".len
  var maxAgeLen = "Age".len
  var maxModelLen = "Model".len
  var maxDescriptionLen = "Description".len

  const totalWidth = 132
  const fixedSeparatorWidth = " | ".len * 3       # Three separators
  const sessionIdFixedLen = 36 # UUID length

  # Calculate available width for description
  var descriptionAvailableWidth = totalWidth - sessionIdFixedLen - fixedSeparatorWidth - maxAgeLen - maxModelLen

  for file in walkDir(session.sessionDir):
    if file.kind == pcFile and file.path.endsWith(".json"):
      let sessionId = file.path.splitFile().name
      let sessionFile = session.getSessionFilePath(sessionId)
      try:
        let lastModified = getLastModificationTime(sessionFile)
        let age = getTime() - lastModified
        let sessionObj = session.loadSession(sessionId)
        if sessionObj.messages.len > 0:
          var description = sessionObj.messages[0].content.strip().splitLines()[0]
          let lastModel = if sessionObj.messages[^1].role == assistant: sessionObj.messages[^1].model else: ""
          let formattedAge = formatAge(age)

          # Truncate description if too long
          if description.len > descriptionAvailableWidth:
            description = description[0 ..< (descriptionAvailableWidth - 3)] & "..."

          sessionData.add((sessionId, age, formattedAge, lastModel, description))

          maxSessionIdLen = max(maxSessionIdLen, sessionId.len)
          maxAgeLen = max(maxAgeLen, formattedAge.len)
          maxModelLen = max(maxModelLen, lastModel.len)
          maxDescriptionLen = max(maxDescriptionLen, description.len)
        else:
          sessionData.add((sessionId, initDuration(0), "(empty)", "(empty)", "(empty)"))
          maxSessionIdLen = max(maxSessionIdLen, sessionId.len)
          maxAgeLen = max(maxAgeLen, "(empty)".len)
          maxModelLen = max(maxModelLen, "(empty)".len)
          maxDescriptionLen = max(maxDescriptionLen, "(empty)".len)
      except Exception as e:
        corruptFiles.add(sessionFile)
        # Corrupt files don't participate in column width calculation

      # Sort sessionData by age (rawAge)
  sessionData.sort(proc (a, b: tuple[sessionId: string, rawAge: Duration,
      formattedAge: string, model: string, description: string]): int =
    result = cmp(a.rawAge, b.rawAge)
  )

  echo "Session ID".align(sessionIdFixedLen) & " | " &
       "Age".align(maxAgeLen) & " | " &
       # "Model".align(maxModelLen) & " | " &
    "Description".align(maxDescriptionLen)

  echo "-".repeat(sessionIdFixedLen) & "-+-" &
       "-".repeat(maxAgeLen) & "-+-" &
       # "-".repeat(maxModelLen) & "-+-" &
    "-".repeat(maxDescriptionLen)

  for data in sessionData:
    let (sessionId, rawAge, age, model, description) = data
    echo sessionId.align(sessionIdFixedLen) & " | " &
         age.align(maxAgeLen) & " | " &
         # model.align(maxModelLen) & " | " &
      description.align(maxDescriptionLen)

  if corruptFiles.len > 0:
    echo "\nFound " & $corruptFiles.len & " corrupt session files."
    if isatty(stdin):
      stdout.write "Do you want to delete them? (y/N) "
      let response = stdin.readLine().strip().toLowerAscii()
      if response == "y":
        for filePath in corruptFiles:
          try:
            removeFile(filePath)
            echo "Deleted " & filePath
          except Exception as e:
            echo "Failed to delete " & filePath & ": " & e.msg
      else:
        echo "Corrupt files not deleted."
    else:
      echo "Corrupt files found but not deleted (not running in interactive terminal)."

proc prune*(days: int = 10) =
  ## Deletes all sessions older than the specified number of days.
  if not dirExists(session.sessionDir):
    echo "No sessions found."
    return

  var prunedCount = 0
  for file in walkDir(session.sessionDir):
    if file.kind == pcFile and file.path.endsWith(".json"):
      let sessionFile = file.path
      let lastModified = getLastModificationTime(sessionFile)
      let age = getTime() - lastModified

      if age.inDays > days:
        let sessionId = file.path.splitFile().name
        removeFile(sessionFile)
        echo "Deleted session " & sessionId
        prunedCount += 1

  if prunedCount == 0:
    echo "No sessions to prune."
  else:
    echo "Pruned " & $prunedCount & " sessions."
