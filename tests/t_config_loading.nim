import std/tables
import os
import unittest

import seance/[config, providers, types]

suite "Configuration Loading":
  let testConfigDir = "temp_test_config"
  let testConfigPath = testConfigDir / "config.ini"

  setup:
    createDir(testConfigDir)

  teardown:
    removeDir(testConfigDir)

  test "loads a valid INI config file":
    let content = """
[seance]
default_provider = openai
auto_session = false

[openai]
key = sk-12345
model = gpt-4o

[gemini]
key = gem-abcdef
# model is optional
"""
    writeFile(testConfigPath, content)
    setConfigPath(testConfigPath)
    let config = config.loadConfig()
    check config.defaultProvider == OpenAI
    check config.autoSession == false
    check config.providers.len == 2
    check config.providers["openai"].key == "sk-12345"
    check config.providers["openai"].model == "gpt-4o"
    check config.providers["gemini"].key == "gem-abcdef"
    check config.providers["gemini"].model == ""

  test "raises ConfigError for missing file":
    setConfigPath("non_existent_file.ini")
    expect ConfigError:
      discard config.loadConfig()

  test "raises ConfigError for missing key":
    let content = "[openai]\nmodel = gpt-4o"
    writeFile(testConfigPath, content)
    setConfigPath(testConfigPath)
    expect ConfigError:
      discard config.loadConfig()

  test "raises ConfigError for parsing error":
    let content = """
[openai
key = bad-ini
"""
    writeFile(testConfigPath, content)
    setConfigPath(testConfigPath)
    try:
      discard config.loadConfig()
      fail()
    except ConfigError as e:
      check(e.msg.len > 0)