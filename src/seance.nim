from seance/session import newChatSession
from seance/providers import getProvider
export newChatSession, getProvider

# This is the main entry point for the executable.
# It uses cligen to dispatch to the correct command implementation.
import cligen
import seance/commands # Import the module containing our command procedures

dispatchMulti(
  [
    commands.chat,
    help = {
      "prompt": "The prompt to send to the LLM. Can be combined with stdin input.",
      "model": "The specific model to use (overrides config).",
      "systemPrompt": "An optional system prompt to guide the model's response.",
      "verbose": "Set verbosity level (0=info, 1=debug, 2=all).",
      "dryRun": "If true, prints the final prompt instead of sending it to the LLM.",
      "noSession": "If true, no session will be loaded or saved."
    },
  ],
  [commands.list],
  [commands.prune, help = {"days": "The number of days to keep sessions."}],
  [commands.version],
)
