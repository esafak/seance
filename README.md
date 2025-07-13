# Séance

[![GitHub workflow status](https://github.com/esafak/seance/actions/workflows/release.yml/badge.svg)](https://github.com/esafak/seance/actions/workflows/release.yml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/esafak/seance)](https://github.com/emre/seance/releases)
[![GitHub license](https://img.shields.io/github/license/esafak/seance)](LICENSE)

A CLI tool and library for interacting with various Large Language Models (LLMs).

Séance provides a unified interface to communicate with different providers like OpenAI, Google Gemini, and Anthropic directly from your terminal.

## Features

- **Unified CLI**: A single command to interact with multiple LLM providers.
- **Provider Support**: Currently supports OpenAI, Google Gemini, and Anthropic.
- **Simple Configuration**: Configure all your API keys in a single TOML file.
- **Extensible**: Designed to be easily extendable with new providers.

## Installation

You can install Seance using `nimble`:

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

- **Pruning Sessions**: To clean up old sessions, you can use the `prune` command. This will delete all sessions older than a specified number of days (default is 10).

  ```bash
  # Prune sessions older than 10 days
  seance prune

  # Prune sessions older than 30 days
  seance prune --days 30
  ```

## Using as a Library

You can also import `seance` into your Nim projects to programmatically interact with LLMs.

First, add `seance` to your project's dependencies:

```bash
nimble add seance
```

Here's a basic example of how to use `seance` in your Nim code:

```nim
import seance/providers

when isMainModule:
  # Initialize a provider (e.g., OpenAI)
  # The API key and model will be loaded from your config.ini or environment variables
  let openaiProvider = newOpenAIProvider()

  # Send a chat message
  let response = waitFor openaiProvider.chat("Hello, how are you?")
  echo "OpenAI Response: ", response

  # Initialize a Gemini provider
  let geminiProvider = newGeminiProvider()
  let geminiResponse = waitFor geminiProvider.chat("Tell me a fun fact about Nim programming language.")
  echo "Gemini Response: ", geminiResponse

  # You can also specify a custom model or API key if needed
  # let customOpenAIProvider = newOpenAIProvider(model = "gpt-3.5-turbo", apiKey = "sk-your-custom-key")
  # let customResponse = waitFor customOpenAIProvider.chat("What's the weather like today?")
  # echo "Custom OpenAI Response: ", customResponse
```

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
