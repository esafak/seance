import std/tables
import os
import unittest

import seance/config

suite "Configuration Loading":
  let testConfigDir = "temp_test_config"
  let testConfigPath = testConfigDir / "config.toml"

  setup:
    createDir(testConfigDir)

  teardown:
    removeDir(testConfigDir)

  test "loads a valid config file":
    let content = """
default_provider = "openai"

[openai]
key = "sk-12345"
model = "gpt-4o"

[gemini]
key = "gem-abcdef"
# model is optional
"""
    writeFile(testConfigPath, content)
    let config = loadConfig(testConfigPath)
    check config.defaultProvider == "openai"
    check config.providers.len == 2
    check config.providers["openai"].key == "sk-12345"
    check config.providers["openai"].model == "gpt-4o"
    check config.providers["gemini"].key == "gem-abcdef"
    check config.providers["gemini"].model == ""

  test "raises ConfigError for missing file":
    expect ConfigError:
      discard loadConfig("non_existent_file.toml")

  test "raises ConfigError for missing key":
    let content = "[openai]\nmodel = \"gpt-4o\""
    writeFile(testConfigPath, content)
    expect ConfigError:
      discard loadConfig(testConfigPath)

  test "raises ConfigError for TOML parsing error":
    let content = """
[openai
key = "bad-toml"
"""
    writeFile(testConfigPath, content)
    expect ConfigError:
      discard loadConfig(testConfigPath)