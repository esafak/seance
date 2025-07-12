# Seance

[![GitHub workflow status](https://github.com/esafak/seance/actions/workflows/release.yml/badge.svg)](https://github.com/esafak/seance/actions/workflows/release.yml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/esafak/seance)](https://github.com/emre/seance/releases)
[![GitHub license](https://img.shields.io/github/license/esafak/seance)](LICENSE)

A CLI tool and library for interacting with various Large Language Models (LLMs).

Seance provides a unified interface to communicate with different providers like OpenAI, Google Gemini, and Anthropic directly from your terminal.

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

Before using Seance, you need to configure your API keys. Create a configuration file at `~/.config/seance/config.toml`.

Here is an example configuration:

```toml
# ~/.config/seance/config.toml
default_provider = "gemini"

[openai]
key = "sk-..."
model = "gpt-4.1-nano-2025-04-14"

[gemini]
key = "..."

[anthropic]
key = "..."
```

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

Seance supports session management, allowing you to continue conversations and manage session history.

By default, Seance will automatically create a session for each conversation. You can disable this behavior by setting `auto_session = false` in your `~/.config/seance/config.toml` file.

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

## Development

To contribute to Seance or run it from the source:

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
