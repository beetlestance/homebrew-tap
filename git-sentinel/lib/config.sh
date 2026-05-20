#!/usr/bin/env bash
# config.sh — sentinel.yml parser
# Requires: yq, log.sh (sourced before this)
# Expects: CONFIG_PATH set by caller

resolve_config_path() {
  local path="$1"
  local base_dir="$2"

  case "$path" in
    /*) ;;
    *) path="$base_dir/$path" ;;
  esac

  if [[ -d "$path" ]]; then
    cd "$path" && pwd
  else
    echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
  fi
}

parse_config() {
  [[ -f "$CONFIG_PATH" ]] || { log_fail "config not found: $CONFIG_PATH"; exit "$EXIT_CONFIG_ERROR"; }

  local config_dir
  config_dir=$(cd "$(dirname "$CONFIG_PATH")" && pwd)

  ORG=$(yq '.org // ""' "$CONFIG_PATH")
  REPO_NAME=$(yq '.repo // ""' "$CONFIG_PATH")
  VISIBILITY=$(yq '.visibility // "private"' "$CONFIG_PATH")
  DESCRIPTION=$(yq '.description // ""' "$CONFIG_PATH")
  REQUIRED_REVIEWS=$(yq '.required_reviews // 0' "$CONFIG_PATH")
  README_PATH=$(yq '.readme // ""' "$CONFIG_PATH")
  LICENSE=$(yq '.license // ""' "$CONFIG_PATH")
  DELETE_BRANCH_ON_MERGE=$(yq '.delete_branch_on_merge // true' "$CONFIG_PATH")
  REQUIRE_CODE_OWNER_REVIEW=$(yq '.require_code_owner_review // false' "$CONFIG_PATH")

  BYPASS_USERS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && BYPASS_USERS+=("$line")
  done < <(yq '.bypass_actors.users[]' "$CONFIG_PATH" 2>/dev/null)

  BYPASS_TEAMS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && BYPASS_TEAMS+=("$line")
  done < <(yq '.bypass_actors.teams[]' "$CONFIG_PATH" 2>/dev/null)

  BYPASS_APPS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && BYPASS_APPS+=("$line")
  done < <(yq '.bypass_actors.apps[]' "$CONFIG_PATH" 2>/dev/null)

  COLLABORATORS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && COLLABORATORS+=("$line")
  done < <(yq '.collaborators[]' "$CONFIG_PATH" 2>/dev/null)

  TEMPLATES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && TEMPLATES+=("$line")
  done < <(yq '.templates[]' "$CONFIG_PATH" 2>/dev/null)

  RULESET_PATHS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && RULESET_PATHS+=("$line")
  done < <(yq '.rulesets[]' "$CONFIG_PATH" 2>/dev/null)

  # Resolve relative paths to absolute so they survive cd into work directories
  if [[ -n "$README_PATH" ]]; then
    README_PATH=$(resolve_config_path "$README_PATH" "$config_dir")
  fi

  local resolved=()
  for tmpl in "${TEMPLATES[@]}"; do
    resolved+=("$(resolve_config_path "$tmpl" "$config_dir")")
  done
  TEMPLATES=("${resolved[@]}")

  resolved=()
  for ruleset in "${RULESET_PATHS[@]}"; do
    resolved+=("$(resolve_config_path "$ruleset" "$config_dir")")
  done
  RULESET_PATHS=("${resolved[@]}")
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

  for ruleset in "${RULESET_PATHS[@]}"; do
    if [[ ! -f "$ruleset" ]]; then
      log_fail "ruleset path does not exist: $ruleset"
      exit "$EXIT_CONFIG_ERROR"
    fi

    if ! jq empty "$ruleset" >/dev/null 2>&1; then
      log_fail "ruleset is not valid JSON: $ruleset"
      exit "$EXIT_CONFIG_ERROR"
    fi

    if [[ "$(jq -r '.name // ""' "$ruleset")" == "" ]]; then
      log_fail "ruleset JSON must include a name: $ruleset"
      exit "$EXIT_CONFIG_ERROR"
    fi
  done

  log_ok "config validated: $ORG/$REPO_NAME"
}
