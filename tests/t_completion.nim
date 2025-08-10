import std/[json, os, strutils, syncio, tempfiles, unittest]
import seance/completion
import yaml

const yamlPath = joinPath("carapace.yaml")
const carapaceYaml = readFile(yamlPath)

suite "Carapace completion":
  test "completion procedure outputs the spec":
    check completion() == carapaceYaml
    echo(len(completion()), ",", len(carapaceYaml))

suite "YAML validation":
  test "carapace.yaml is valid YAML":
    var parsed: YamlNode
    load(carapaceYaml, parsed) # This will raise an exception if the YAML is invalid