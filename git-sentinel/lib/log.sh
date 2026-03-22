#!/usr/bin/env bash
# log.sh — sourced by git-sentinel, not executed directly

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_CONFIG_ERROR=1
readonly EXIT_GITHUB_ERROR=2
readonly EXIT_FS_ERROR=3

# Logging functions
if [[ -t 1 ]]; then
  log_ok()   { echo "[ok]   $1"; }
  log_skip() { echo "[skip] $1"; }
  log_info() { echo "[info] $1"; }
else
  log_ok()   { echo "ok: $1"; }
  log_skip() { echo "skip: $1"; }
  log_info() { echo "info: $1"; }
fi

if [[ -t 2 ]]; then
  log_warn() { echo "[warn] $1" >&2; }
  log_fail() { echo "[fail] $1" >&2; }
else
  log_warn() { echo "warn: $1" >&2; }
  log_fail() { echo "fail: $1" >&2; }
fi
