import os, parsetoml, tables

type
  ProviderConfig* = object
    key*: string
    model*: string

  Config* = object
    providers*: Table[string, ProviderConfig]
    defaultProvider*: string
    autoSession*: bool

  ConfigError* = object of CatchableError

proc getConfigPath*(): string =
  ## Returns the standard path for the config file.
  let home = getHomeDir()
  let configDir = home / ".config" / "seance"
  return configDir / "config.toml"

proc loadConfig*(path: string = ""): Config =
  ## Loads and parses the TOML config file.
  ## Raises ConfigError if the file is not found or has validation errors.
  let configPath = if path.len > 0: path else: getConfigPath()

  if not fileExists(configPath):
    raise newException(ConfigError, "Config file not found at: " & configPath &
      "\nPlease create it with your API keys.")

  let toml = try:
    parseFile(configPath)
  except TomlError as e:
    raise newException(ConfigError, "Failed to parse config file '" & configPath & "': " & e.msg)


  # Read the top-level default_provider. Default to "openai" if not present.
  var defaultProvider = "openai"
  if toml.hasKey("default_provider"):
    let dp = toml["default_provider"].getStr()
    if dp.len > 0:
      defaultProvider = dp

  var autoSession = true
  if toml.hasKey("auto_session"):
    autoSession = toml["auto_session"].getBool(true)

  var providersTable = initTable[string, ProviderConfig]()
  for section, table in toml.tableVal.pairs:
    if section == "default_provider" or section == "auto_session" or table.kind != TomlValueKind.Table:
      continue # Skip the default_provider key and other non-table sections at the root

    let key = table.getOrDefault("key").getStr("")
    let model = table.getOrDefault("model").getStr("")

    if key.len == 0:
      raise newException(ConfigError, "API key ('key') is missing for provider [" & section & "] in " & configPath)

    providersTable[section] = ProviderConfig(key: key, model: model)

  return Config(providers: providersTable, defaultProvider: defaultProvider, autoSession: autoSession)