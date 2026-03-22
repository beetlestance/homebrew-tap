#!/usr/bin/env bash
# config.sh — sentinel.yml parser
# Requires: yq, log.sh (sourced before this)
# Expects: CONFIG_PATH set by caller

parse_config() {
  [[ -f "$CONFIG_PATH" ]] || { log_fail "config not found: $CONFIG_PATH"; exit "$EXIT_CONFIG_ERROR"; }

  ORG=$(yq '.org // ""' "$CONFIG_PATH")
  REPO_NAME=$(yq '.repo // ""' "$CONFIG_PATH")
  VISIBILITY=$(yq '.visibility // "private"' "$CONFIG_PATH")
  DESCRIPTION=$(yq '.description // ""' "$CONFIG_PATH")
  REQUIRED_REVIEWS=$(yq '.required_reviews // 0' "$CONFIG_PATH")
  README_PATH=$(yq '.readme // ""' "$CONFIG_PATH")
  LICENSE=$(yq '.license // ""' "$CONFIG_PATH")
  DELETE_BRANCH_ON_MERGE=$(yq '.delete_branch_on_merge // true' "$CONFIG_PATH")
  REQUIRE_CODE_OWNER_REVIEW=$(yq '.require_code_owner_review // false' "$CONFIG_PATH")

  COLLABORATORS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && COLLABORATORS+=("$line")
  done < <(yq '.collaborators[]' "$CONFIG_PATH" 2>/dev/null)

  TEMPLATES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && TEMPLATES+=("$line")
  done < <(yq '.templates[]' "$CONFIG_PATH" 2>/dev/null)

  # Resolve relative paths to absolute so they survive cd into work directories
  if [[ -n "$README_PATH" ]]; then
    README_PATH=$(cd "$(dirname "$README_PATH")" && pwd)/$(basename "$README_PATH")
  fi

  local resolved=()
  for tmpl in "${TEMPLATES[@]}"; do
    if [[ -d "$tmpl" ]]; then
      resolved+=("$(cd "$tmpl" && pwd)")
    else
      resolved+=("$(cd "$(dirname "$tmpl")" && pwd)/$(basename "$tmpl")")
    fi
  done
  TEMPLATES=("${resolved[@]}")
}

validate_config() {
  [[ -n "$ORG" ]] || { log_fail "org is required in $CONFIG_PATH"; exit "$EXIT_CONFIG_ERROR"; }
  [[ -n "$REPO_NAME" ]] || { log_fail "repo is required in $CONFIG_PATH"; exit "$EXIT_CONFIG_ERROR"; }

  if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
    log_fail "visibility must be 'public' or 'private', got '$VISIBILITY'"
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ -n "$README_PATH" && ! -f "$README_PATH" ]]; then
    log_fail "readme path does not exist: $README_PATH"
    exit "$EXIT_CONFIG_ERROR"
  fi

  for tmpl in "${TEMPLATES[@]}"; do
    if [[ ! -f "$tmpl" && ! -d "$tmpl" ]]; then
      log_fail "template path does not exist: $tmpl"
      exit "$EXIT_CONFIG_ERROR"
    fi
  done

  log_ok "config validated: $ORG/$REPO_NAME"
}
