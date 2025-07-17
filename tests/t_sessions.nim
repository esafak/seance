import seance/session
import seance/commands
import seance/config
import seance/providers
import seance/providers/common

import options
import os
import times
import unittest

type MockProvider = ref object of ChatProvider
method dispatchChat(provider: MockProvider, messages: seq[ChatMessage], model: string = ""): ChatResult =
  return ChatResult(content: "bar", model: "gpt-4")

suite "Session Management":
  var oldSessionDir: string

  setup:
    oldSessionDir = session.sessionDir
    session.sessionDir = "./test_sessions"
    createDir(session.sessionDir)
    let configDir = "./test_config"
    createDir(configDir)
    let configFile = configDir / "config.ini"
    writeFile(configFile, "[seance]\ndefault_provider=openai\n[openai]\nkey=test\nmodel=gpt-4")
    setConfigPath(configFile)

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

  test "Chatting in a session":
    # 1. Create a mock ChatProvider
    let mockProvider: Option[Provider] = some(Provider(MockProvider()))

    # 2. Create a session and chat
    var sess = newChatSession()
    let result = sess.chat("foo", mockProvider)

    # 3. Assertions
    check(sess.messages.len == 2)
    check(sess.messages[0].role == user)
    check(sess.messages[0].content == "foo")
    check(sess.messages[1].role == assistant)
    check(sess.messages[1].content == "bar")
    check(sess.messages[1].model == "gpt-4")
    check(result.content == "bar")
    check(result.model == "gpt-4")

