import unittest
import os
import times
import seance/session
import seance/commands

suite "Session Management":
  var oldSessionDir: string

  setup:
    oldSessionDir = session.sessionDir
    session.sessionDir = "./test_sessions"
    createDir(session.sessionDir)

  teardown:
    removeDir(session.sessionDir)
    session.sessionDir = oldSessionDir

  test "Prune old sessions":
    # Create a dummy session file older than 10 days
    let oldSessionId = "old_session"
    let oldSessionFile = getSessionFilePath(oldSessionId)
    writeFile(oldSessionFile, "{}")
    let oldTime = getTime() - initDuration(days = 11)
    setLastModificationTime(oldSessionFile, oldTime)

    # Create a dummy session file newer than 10 days
    let newSessionId = "new_session"
    let newSessionFile = getSessionFilePath(newSessionId)
    writeFile(newSessionFile, "{}")

    prune(days = 10)

    check(not fileExists(oldSessionFile))
    check(fileExists(newSessionFile))

  test "List command handles corrupt sessions without crashing":
    # Create a corrupt session file
    let corruptSessionId = "corrupt_session"
    let corruptSessionFile = getSessionFilePath(corruptSessionId)
    writeFile(corruptSessionFile, "{invalid json")

    # Call list command (it will print to console and prompt for deletion)
    list()

    # Assert that the corrupt file still exists (since we don't provide 'y' input)
    check(fileExists(corruptSessionFile))

    # Clean up the corrupt file manually
    removeFile(corruptSessionFile)

