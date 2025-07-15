from defaults import DefaultProvider
import types

import os, tables, streams
import std/[logging, parsecfg, strutils]

var customConfigPath: string

proc setConfigPath*(path: string) =
  customConfigPath = path

proc getConfigPath*(): string =
  if customConfigPath.len > 0:
    return customConfigPath
  else:
    return getHomeDir() / ".config" / "seance" / "config.ini"

proc loadConfig*(): SeanceConfig =
  ## Loads and parses the INI config file.
  ## It automatically finds the config file in the default location.
  ## Raises ConfigError on validation errors.
  let configPath = getConfigPath()

  if not fileExists(configPath):
    raise newException(ConfigError, "Config file not found at: " & configPath &
      "\nPlease create it with your API keys.")

  var p: CfgParser
  var f: Stream
  try:
    f = newFileStream(configPath, fmRead)
  except IOError as e:
    raise newException(ConfigError, "Cannot open config file: " & e.msg)

  open(p, f, configPath)

  var providersTable = initTable[string, ProviderConfig]()
  var defaultProvider = DefaultProvider  # Default to Gemini enum value
  var autoSession = true
  var currentSection = ""

  while true:
    let e = next(p)
    case e.kind
    of cfgEof:
      break
    of cfgSectionStart:
      currentSection = e.section
    of cfgKeyValuePair:
      case currentSection
      of "seance":
        case e.key
        of "default_provider":
          try:
            defaultProvider = parseProvider(e.value)
          except ConfigError as e:
            close(p)
            raise newException(ConfigError, e.msg)
        of "auto_session":
          try:
            autoSession = parseBool(e.value)
          except ValueError:
            close(p)
            raise newException(ConfigError, "Invalid boolean value for 'auto_session' in " & configPath)
        else:
          discard
      else:
        if not providersTable.hasKey(currentSection):
          providersTable[currentSection] = ProviderConfig(key: "", model: "")
        case e.key
        of "key":
          providersTable[currentSection].key = e.value
        of "model":
          providersTable[currentSection].model = e.value
        else:
          discard
    of cfgOption:
      discard
    of cfgError:
      let errorMsg = p.errorStr(e.msg)
      close(p)
      raise newException(ConfigError, errorMsg)

  close(p)

  for section, providerConfig in providersTable.pairs:
    if providerConfig.key.len == 0:
      raise newException(ConfigError, "API key ('key') is missing for provider [" & section & "] in " & configPath)

  debug "Config loaded. Default provider: " & $defaultProvider & ", auto session: " & $autoSession
  return SeanceConfig(providers: providersTable, defaultProvider: defaultProvider, autoSession: autoSession)