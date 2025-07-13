import std/tables
import os, strutils
import unittest
import std/parsecfg

import seance/config

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
    let config = config.loadConfig(testConfigPath)
    check config.defaultProvider == "openai"
    check config.autoSession == false
    check config.providers.len == 2
    check config.providers["openai"].key == "sk-12345"
    check config.providers["openai"].model == "gpt-4o"
    check config.providers["gemini"].key == "gem-abcdef"
    check config.providers["gemini"].model == ""

  test "raises ConfigError for missing file":
    expect ConfigError:
      discard config.loadConfig("non_existent_file.ini")

  test "raises ConfigError for missing key":
    let content = "[openai]\nmodel = gpt-4o"
    writeFile(testConfigPath, content)
    expect ConfigError:
      discard config.loadConfig(testConfigPath)

  test "raises ConfigError for parsing error":
    let content = """
[openai
key = bad-ini
"""
    writeFile(testConfigPath, content)
    try:
      discard config.loadConfig(testConfigPath)
      fail()
    except ConfigError as e:
      check(e.msg.len > 0)