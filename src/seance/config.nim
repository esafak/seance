from defaults import DefaultProvider, DefaultModels
import types

import os, tables, streams
import std/[logging, parsecfg, strutils, terminal, sequtils]

var customConfigPath: string

proc setConfigPath*(path: string) =
  customConfigPath = path

proc getConfigPath*(): string =
  if customConfigPath.len > 0:
    return customConfigPath
  else:
    return getHomeDir() / ".config" / "seance" / "config.ini"

proc createConfigWizard(): SeanceConfig

proc loadConfig*(): SeanceConfig =
  ## Loads and parses the INI config file.
  ## It automatically finds the config file in the default location.
  ## Raises ConfigError on validation errors.
  let configPath = getConfigPath()

  if not fileExists(configPath):
    return createConfigWizard()

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

proc createConfigWizard(): SeanceConfig =
  let configPath = getConfigPath()
  if not isatty(stdin):
    raise newException(ConfigError, "Config file not found at: " & configPath &
      "\nPlease create it with your API keys.")

  echo "Welcome to Seance! Let's get you set up."

  # Ensure the directory exists
  let configDir = configPath.parentDir
  if not dirExists(configDir):
    createDir(configDir)

  var providerStr: string
  var providerNames: seq[string]
  for p in low(Provider)..high(Provider):
    providerNames.add($p)

  let providerValues = providerNames.map(proc (p: string): string = p.toLower)

  while true:
    echo "First, pick a provider. Supported providers are: " & providerNames.join(", ")
    stdout.write "Provider: "
    providerStr = stdin.readLine.strip.toLower
    if providerStr in providerValues:
      break
    else:
      echo "Invalid provider. Please choose from the list."

  stdout.write "Now, enter your API key: "
  let apiKey = stdin.readLine.strip

  let providerName = providerStr
  let providerEnum = parseProvider(providerName)

  let model = DefaultModels[providerEnum]

  # Create the config content
  let content = """
[seance]
default_provider = $1

[$1]
key = $2
model = $3
""" % [providerName, apiKey, model]

  try:
    writeFile(configPath, content)
    echo "Config file created at: " & configPath
  except IOError as e:
    raise newException(ConfigError, "Failed to write config file: " & e.msg)

  var providersTable = initTable[string, ProviderConfig]()
  providersTable[providerName] = ProviderConfig(key: apiKey, model: model)

  return SeanceConfig(
    providers: providersTable,
    defaultProvider: providerEnum,
    autoSession: true
  )