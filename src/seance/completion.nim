import std/os

proc completion*() : string =
  ## Outputs the completion script for the specified shell.
  const carapaceYaml = currentSourcePath().parentDir().parentDir().parentDir() / "carapace.yaml"
  const carapaceSpec = staticRead(carapaceYaml)
  result = carapaceSpec
