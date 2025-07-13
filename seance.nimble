# Package

version       = "0.2.0"
author        = "Emre Şafak"
description   = "A CLI tool and library for interacting with various LLMs"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["seance"]


# Dependencies

requires "nim >= 2.0"
requires "cligen >= 1.8.6"
requires "jsony >= 1.1.5"
requires "parsetoml >= 0.7.1"
