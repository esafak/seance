import config
import providers

import strutils, tables
import std/logging
import std/os
import std/strutils
import std/terminal

proc newProviderByName(name: string, conf: ProviderConfig): LLMProvider =
  ## Factory function to create a provider instance from its name.
  case name.toLowerAscii():
    of "anthropic": return newAnthropicProvider(conf)
    of "gemini": return newGeminiProvider(conf)
    of "openai": return newOpenAIProvider(conf)
    else: raise newException(ConfigError, "Unknown or unsupported provider: " & name)

proc chat*(prompt: seq[string], provider: string = "", model: string = "", systemPrompt: string = "", verbose: int = 0, dryRun: bool = false) =
  ## Sends a single chat prompt to the specified provider and prints the response.
  var stdinContent = ""
  if not isatty(stdin):
    stdinContent = stdin.readAll()

  var finalPrompt: string = ""
  if prompt.len > 0 and stdinContent.len > 0:
    finalPrompt = prompt.join(" ") & "\n\n" & stdinContent
  elif prompt.len > 0:
    finalPrompt = prompt.join(" ")
  elif stdinContent.len > 0:
    finalPrompt = stdinContent
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

  let config = try:
    loadConfig()
  except ConfigError as e:
    error "Configuration Error: " & e.msg
    quit(1)

  # Determine which provider to use
  let actualProviderName = if provider.len > 0: provider else: config.defaultProvider
  if actualProviderName.len == 0:
    error "No provider specified and no default provider found in config. " &
      "Please specify a provider or set 'default_provider' in your config file."
    quit(1)

  var providerConf: ProviderConfig
  if not config.providers.hasKey(actualProviderName):
    error "Provider '" & actualProviderName & "' not found in configuration."
    quit(1)

  providerConf = config.providers[actualProviderName]

  # Override model if specified via CLI
  if model.len > 0:
    providerConf.model = model

  if providerConf.key.len == 0:
    error "API key for provider '" & actualProviderName & "' is not set in configuration."
    quit(1)

  var messages: seq[ChatMessage]
  if systemPrompt.len > 0:
    messages.add(ChatMessage(role: system, content: systemPrompt))
  messages.add(ChatMessage(role: user, content: finalPrompt))

  try:
    var llmProvider = newProviderByName(actualProviderName, providerConf)
    let result = llmProvider.chat(messages)
    info "Using " & result.model
    echo result.content
  except Exception as e:
    error "An error occurred during chat: " & e.msg
    quit(1)

proc version*() =
  ## Displays the current version of the LLM Client.
  let nimbleFilePath = "seance.nimble" # Path to your nimble file

  if fileExists(nimbleFilePath):
    for line in lines(nimbleFilePath):
      if line.startsWith("version"):
        # Extract the version string, e.g., "0.1.0"
        let parts = line.split("=")
        if parts.len == 2:
          let rawVersion = parts[1].strip()
          # Remove quotes if present
          let cleanVersion = rawVersion.replace("\"", "").replace("'", "")
          echo cleanVersion
          return
    echo "LLM Client Version: (not found in .nimble file)"
  else:
    echo "LLM Client Version: (seance.nimble file not found)"