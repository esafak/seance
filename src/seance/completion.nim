import std/os

proc completion*(shell: string) =
  ## Outputs the completion script for the specified shell.
  const carapaceSpec = staticRead(currentSourcePath().parentDir().parentDir().parentDir() / "carapace.yaml")
  echo carapaceSpec
