# Séance

[![GitHub workflow status](https://github.com/esafak/seance/actions/workflows/release.yml/badge.svg)](https://github.com/esafak/seance/actions/workflows/release.yml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/esafak/seance)](https://github.com/emre/seance/releases)
[![GitHub license](https://img.shields.io/github/license/esafak/seance)](LICENSE)

A CLI tool and library for interacting with various Large Language Models (LLMs).

Séance provides a unified interface to communicate with different providers like OpenAI, Google Gemini, and Anthropic directly from your terminal.

## Features

- **Unified CLI**: A single command to interact with multiple LLM providers.
- **Provider Support**: Currently supports OpenAI, Google Gemini, Anthropic, and OpenRouter.
- **Simple Configuration**: Configure all your API keys in a single INI file.
- **Extensible**: Designed to be easily extendable with new providers.

## Installation

You can install Séance using `nimble`:

```bash
nimble install seance
```

## Getting Started

### 1. Configuration

Before using Séance, you need to configure your API keys. Create a configuration file at `~/.config/seance/config.ini`.

Here is an example configuration:

```ini
# ~/.config/seance/config.ini
[seance]
default_provider = gemini
auto_session = true

[openai]
key = sk-...
model = gpt-4.1-nano-2025-04-14

[gemini]
key = ...

[anthropic]
key = ...

[openrouter]
key = ...
```

If your configuration file becomes corrupted, Séance will detect it and offer to delete the file for you.

### 2. Usage

Once configured, you can use the `seance` command to interact with your chosen LLM.

```bash
# Get a response from the default provider
seance chat "What is the speed of light?"

# Specify a provider for your query
seance chat "Explain the theory of relativity" --provider gemini

# Use piped content as input
cat src/seance.nim | seance chat "Explain what this Nim code does."
```

### 3. Session Management

Séance supports session management, allowing you to continue conversations and manage session history.

By default, Séance will automatically create a session for each conversation. You can disable this behavior by setting `auto_session = false` in your `~/.config/seance/config.ini` file.

- **Listing Sessions**: To see a list of all your active sessions, use the `list` command:

  ```bash
  seance list
  ```

- **Continuing a Session**: To continue a previous conversation, use the `--session` flag with the session ID:

  ```bash
  seance chat "Tell me more about that." --session <session_id>
  ```

- **Pruning Sessions**: To clean up old sessions, you can use the `prune` command. 
This will delete all sessions older than 10 days, or whatever you specify with --days:

  ```bash
  seance prune --days 30
  ```

- **Disabling Session for a Single Chat**: To prevent a session from being loaded or saved for a specific chat, use the `--no_session` flag:

  ```bash
  seance chat "This chat should not be saved." --no_session
  ```

- **Using a JSON Schema**: To force the output to be in a specific JSON format, you can use the `--json` flag. For the Gemini, Anthropic, and OpenAI providers, you can also use the `--schema` flag to provide a JSON schema to which the output must conform.

  ```bash
  # Create a schema file
  echo '{"type": "object", "properties": {"recipe_name": {"type": "string"}}}' > schema.json

  # Use the schema
  seance chat "Give me a recipe for chocolate chip cookies" --provider gemini --json --schema schema.json
  ```

## Using as a Library

Séance provides a clean, simple API for interacting with LLMs programmatically.

### Basic Usage

Just import `seance` and start chatting:

```nim
import seance

# Basic chat with default provider
let response = chat("What is 2 + 2?")
echo response  # "4"

# Conversation context is maintained automatically
let response1 = chat("My name is Alice")
let response2 = chat("What's my name?")  # Remembers "Alice"

# Specify provider and model
let response3 = chat("Tell me a joke", some(OpenAI), some("gpt-4o"))
echo response3

# Add a system prompt
let response4 = chat("Explain recursion", systemPrompt = some("You are a helpful coding assistant"))
echo response4
```

### Session Management

Control conversation context with explicit sessions:

```nim
import seance

# Create sessions with system prompts
var workSession = newSession(some("You are a helpful coding assistant"))
var personalSession = newSession(some("You are a friendly personal assistant"))

# Work conversation - much more intuitive!
let workResponse1 = workSession.chat("How do I optimize SQL queries?", some(OpenAI))
let workResponse2 = workSession.chat("What about indexing?")  # Continues work context

# Personal conversation (separate context)
let personalResponse = personalSession.chat("What's a good pasta recipe?", some(Anthropic))

# Reset global session
resetSession(some("You are now a creative writing assistant"))
let response = chat("Write a short story about a robot")
```

### All Parameters

The `chat` functions support these optional parameters:

```nim
# Global session chat
proc chat*(content: string, 
          provider: Option[Provider] = none(Provider),     # OpenAI, Anthropic, Gemini, OpenRouter
          model: Option[string] = none(string),            # Override model from config
          systemPrompt: Option[string] = none(string),      # Set system prompt
          schema: Option[string] = none(string)            # Path to a JSON schema file
         ): string

# Session-specific chat  
proc chat*(session: var Session,
          content: string,
          provider: Option[Provider] = none(Provider), 
          model: Option[string] = none(string),
          systemPrompt: Option[string] = none(string),      # Only used if session is empty
          schema: Option[string] = none(string)            # Path to a JSON schema file
         ): string
```

### JSON Mode

You can also get a JSON response from the providers that support it.

```nim
import seance
import std/json

# Get a JSON response
let response = chat("Give me a recipe for chocolate chip cookies", jsonMode = true)
let jsonResponse = parseJson(response)
echo jsonResponse["recipe_name"].getStr()
```

Both approaches work:
```nim
# Global session
let response = chat("Hello!")

# Explicit session (more intuitive)
var session = newSession()
let response = session.chat("Hello!")
```

That's it! No complex message arrays, no role management, just simple text in and text out with automatic conversation handling.

## Development

To contribute to Séance or run it from the source:

```bash
# 1. Clone the repository
git clone https://github.com/emre/seance.git
cd seance

# 2. Install development dependencies
nimble install -d --accept

# 3. Run the tests
nimble test
```

## License

This project is licensed under the MIT License.
