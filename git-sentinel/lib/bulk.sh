#!/usr/bin/env bash
# bulk.sh — fleet planning commands
# Requires: gh, jq, log.sh, repos.sh (sourced before this)

bulk_usage() {
  cat <<EOF
Usage: git-sentinel bulk plan (--repos <path> | --all --org <org> | --all --user <user>) [options]

Options:
  --repos <path>              File containing repo names or full names, one per line
  --all                       Select all repositories from --org or --user filters
  --org <org>                 Select repositories under an organization
  --user <user>               Select repositories under a personal account
  --visibility <all|public|private>
                              Filter discovered repos by visibility (default: all)
  --archived <all|true|false> Filter discovered repos by archived status (default: false)
EOF
}

bulk_validate() {
  if [[ "$BULK_COMMAND" != "plan" ]]; then
    log_fail "bulk requires a subcommand"
    bulk_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_ALL" == true && -n "$BULK_REPOS_FILE" ]]; then
    log_fail "use either --all or --repos, not both"
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_ALL" != true && -z "$BULK_REPOS_FILE" ]]; then
    log_fail "bulk plan requires --repos <path> or --all"
    bulk_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_ALL" == true && "$REPOS_OWNER_TYPE" != "org" && "$REPOS_OWNER_TYPE" != "user" ]]; then
    log_fail "bulk plan --all requires --org <org> or --user <user>"
    bulk_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ -n "$BULK_REPOS_FILE" && ! -f "$BULK_REPOS_FILE" ]]; then
    log_fail "repo list not found: $BULK_REPOS_FILE"
    exit "$EXIT_CONFIG_ERROR"
  fi
}

bulk_repos_from_file() {
  grep -vE '^[[:space:]]*(#|$)' "$BULK_REPOS_FILE" \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | jq -R -s 'split("\n") | map(select(length > 0))'
}

bulk_repos_from_discovery() {
  repos_list_validate
  repos_list_fetch | jq '[.[].full_name]'
}

bulk_print_plan() {
  local repos="$1"
  local count
  count=$(echo "$repos" | jq 'length')

  log_info "bulk dry run: $count repo(s) selected"
  echo "$repos" | jq -r '.[]' | while IFS= read -r repo; do
    echo "  - $repo"
  done

  plan_list_items "per-repo actions" \
    "read desired policy from $CONFIG_PATH" \
    "validate repo access" \
    "apply or update branch rulesets" \
    "generate or update repository files" \
    "inject configured templates" \
    "add configured collaborators"

  log_ok "bulk dry run complete — no changes made"
}

bulk_plan() {
  bulk_validate
  check_dependencies

  local repos
  if [[ "$BULK_ALL" == true ]]; then
    authenticate
    repos=$(bulk_repos_from_discovery)
  else
    repos=$(bulk_repos_from_file)
  fi

  if [[ -f "$CONFIG_PATH" ]]; then
    log_info "reading config: $CONFIG_PATH"
    parse_config
    validate_config
  else
    log_warn "config not found: $CONFIG_PATH"
    log_warn "bulk plan will show repo selection only"
  fi

  bulk_print_plan "$repos"
}
