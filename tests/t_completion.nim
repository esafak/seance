import unittest
import osproc
import std/strutils

suite "Carapace completion":
  test "completion command outputs the spec":
    let carapaceYaml = readFile("carapace.yaml").strip()
    let output = execProcess("./seance completion --shell bash").strip()
    check(output == carapaceYaml)
