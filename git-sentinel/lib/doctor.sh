#!/usr/bin/env bash
# doctor.sh — local and GitHub readiness checks
# Requires: gh, git, jq, yq, log.sh, github.sh (sourced before this)

doctor_usage() {
  cat <<EOF
Usage: git-sentinel doctor [--config <path>] [--org <org> --repo <repo>]

Checks local tools, GitHub authentication, and optional repository access.
EOF
}

doctor_check_tool() {
  local tool="$1"
  local install_hint="$2"

  if command -v "$tool" &>/dev/null; then
    log_ok "$tool found: $(command -v "$tool")"
  else
    log_fail "$tool not found — install: $install_hint"
    DOCTOR_FAILED=true
  fi
}

doctor_check_auth() {
  if gh auth status &>/dev/null; then
    log_ok "github authenticated"
  else
    log_fail "not authenticated — run: gh auth login"
    DOCTOR_FAILED=true
  fi
}

doctor_check_repo_access() {
  local owner="$1"
  local repo="$2"
  local repo_json rulesets_error visibility

  if [[ -z "$owner" || -z "$repo" ]]; then
    log_skip "repo access (no --org/--user and --repo provided)"
    return
  fi

  if repo_json=$(gh repo view "$owner/$repo" --json visibility,nameWithOwner 2>/dev/null); then
    log_ok "repo access: $owner/$repo"
  else
    log_skip "repo access: $owner/$repo (not found or inaccessible; ok before init)"
    return
  fi

  if gh_api "/repos/$owner/$repo/rulesets" &>/dev/null; then
    log_ok "rulesets API accessible: $owner/$repo"
  else
    rulesets_error=$(gh_api "/repos/$owner/$repo/rulesets" 2>&1 >/dev/null || true)
    visibility=$(echo "$repo_json" | jq -r '.visibility // ""')

    if [[ "$visibility" == "PRIVATE" && "$rulesets_error" == *"Upgrade to GitHub Pro"* ]]; then
      log_skip "rulesets API: $owner/$repo (private repo rulesets require GitHub Pro/Team/Enterprise or public visibility)"
    else
      log_skip "rulesets API: $owner/$repo (not accessible: $rulesets_error)"
    fi
  fi
}

doctor_check_config() {
  if [[ ! -f "$CONFIG_PATH" ]]; then
    log_skip "config validation (not found: $CONFIG_PATH)"
    return
  fi

  log_info "reading config: $CONFIG_PATH"
  parse_config
  validate_config
}

doctor() {
  DOCTOR_FAILED=false

  doctor_check_tool "gh" "brew install gh"
  doctor_check_tool "git" "brew install git"
  doctor_check_tool "jq" "brew install jq"
  doctor_check_tool "yq" "brew install yq"

  if [[ "$DOCTOR_FAILED" == true ]]; then
    log_fail "doctor failed — missing local dependencies"
    exit "$EXIT_CONFIG_ERROR"
  fi

  doctor_check_auth
  doctor_check_config

  local owner="$REPOS_OWNER"
  if [[ -z "$owner" && -n "${ORG:-}" ]]; then
    owner="$ORG"
  fi

  local repo="$DOCTOR_REPO"
  if [[ -z "$repo" && -n "${REPO_NAME:-}" ]]; then
    repo="$REPO_NAME"
  fi

  doctor_check_repo_access "$owner" "$repo"

  if [[ "$DOCTOR_FAILED" == true ]]; then
    log_fail "doctor found issues"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "doctor passed"
}
