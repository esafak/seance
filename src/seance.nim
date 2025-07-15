import seance/commands # Import the module containing our command procedures
from seance/session import newChatSession
from seance/providers import getProvider

import std/options
import cligen
from cligen/argcvt import ArgcvtParams, argKeys

export newChatSession, getProvider

# --- Support Option[T] arguments for cligen (for dispatchMulti) ---
proc argParse[T](dst: var Option[T], dfl: Option[T],
                 a: var ArgcvtParams): bool =
  var uw: T
  if argParse(uw, (dfl.get(uw)), a):
    dst = some(uw)
    return true

# TODO: Fetch the actual values. argHelp shows the default values.
proc argHelp[T](dfl: Option[T], a: var ArgcvtParams): seq[string] =
  @[argKeys(a), $T, (if dfl.isSome: $dfl.get else: "see config file")]

# This is the main entry point for the executable.
# It uses cligen to dispatch to the correct command implementation.
dispatchMulti(
  [
    commands.chat,
    help = {
      "prompt": "Prompt to send to the LLM. Can be combined with stdin input.",
      "provider": "LLM provider to use: OpenAI, Anthropic, or Gemini.",
      "session": "UUID session ID.",
      "model": "LLM model to use.",
      "systemPrompt": "System prompt to guide the model's response.",
      "verbose": "Verbosity level (0=info, 1=debug, 2=all).",
      "dryRun": "If true, prints the final prompt instead of sending it to the LLM.",
      "noSession": "If true, no session will be loaded or saved."
    },
  ],
  [commands.list],
  [commands.prune, help = {"days": "The number of days to keep sessions."}],
  [commands.version],
)
