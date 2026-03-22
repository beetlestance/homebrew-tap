#!/usr/bin/env bash

schema() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cat "${script_dir}/../sentinel.example.yml"
}
