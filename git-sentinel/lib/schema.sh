#!/usr/bin/env bash

schema() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Lives next to this script in lib/ so it ships via the homebrew formula's
  # Dir["git-sentinel/lib/*"] glob without needing an explicit install entry.
  cat "${script_dir}/sentinel.example.yml"
}
