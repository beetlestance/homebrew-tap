#!/usr/bin/env bash
# github.sh — GitHub CLI helpers
# Requires: log.sh, config.sh (sourced before this)

# Wrapper for gh api that prevents MSYS path rewriting on Windows (Git Bash)
# Without this, /repos/org/name gets rewritten to C:/Program Files/Git/repos/...
gh_api() {
  MSYS_NO_PATHCONV=1 gh api "$@"
}

check_dependencies() {
  local missing=0

  command -v gh &>/dev/null || { log_fail "gh not found — install: brew install gh"; missing=1; }
  command -v yq &>/dev/null || { log_fail "yq not found — install: brew install yq"; missing=1; }
  command -v jq &>/dev/null || { log_fail "jq not found — install: brew install jq"; missing=1; }
  command -v git &>/dev/null || { log_fail "git not found — install: brew install git"; missing=1; }

  [[ "$missing" -eq 1 ]] && exit "$EXIT_CONFIG_ERROR"
  log_ok "dependencies satisfied"
}

authenticate() {
  if ! gh auth status &>/dev/null; then
    log_fail "not authenticated — run: gh auth login"
    exit "$EXIT_GITHUB_ERROR"
  fi
  log_ok "github authenticated"
}

add_collaborators() {
  [[ ${#COLLABORATORS[@]} -eq 0 ]] && return 0
  for user in "${COLLABORATORS[@]}"; do
    [[ -z "$user" ]] && continue
    if gh_api --method PUT "/repos/$ORG/$REPO_NAME/collaborators/$user" -f permission=push &>/dev/null; then
      log_ok "collaborator added: $user"
    else
      log_skip "collaborator: $user (already added or failed)"
    fi
  done
}
