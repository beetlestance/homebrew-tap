#!/usr/bin/env bash
# bulk.sh — fleet planning and enforcement commands
# Requires: gh, git, jq, log.sh, repos.sh, config.sh, repo.sh, branches.sh,
#           files.sh, templates.sh, rulesets.sh, github.sh (sourced before this)

bulk_usage() {
  cat <<EOF
Usage: git-sentinel bulk <plan|enforce> (--repos <path> | --all --org <org> | --all --user <user>) [options]

Options:
  --repos <path>              File containing repo names or full names, one per line
  --all                       Select all repositories from --org or --user filters
  --org <org>                 Select repositories under an organization
  --user <user>               Select repositories under a personal account
  --visibility <all|public|private>
                              Filter discovered repos by visibility (default: all)
  --archived <all|true|false> Filter discovered repos by archived status (default: false)
  --format <table|json>       Report format for bulk enforce (default: table)
  --continue-on-error         Continue enforcing remaining repos after a failure
EOF
}

bulk_validate() {
  if [[ "$BULK_COMMAND" != "plan" && "$BULK_COMMAND" != "enforce" ]]; then
    log_fail "bulk requires a subcommand"
    bulk_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_ALL" == true && -n "$BULK_REPOS_FILE" ]]; then
    log_fail "use either --all or --repos, not both"
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_ALL" != true && -z "$BULK_REPOS_FILE" ]]; then
    log_fail "bulk $BULK_COMMAND requires --repos <path> or --all"
    bulk_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_ALL" == true && "$REPOS_OWNER_TYPE" != "org" && "$REPOS_OWNER_TYPE" != "user" ]]; then
    log_fail "bulk $BULK_COMMAND --all requires --org <org> or --user <user>"
    bulk_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ -n "$BULK_REPOS_FILE" && ! -f "$BULK_REPOS_FILE" ]]; then
    log_fail "repo list not found: $BULK_REPOS_FILE"
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$BULK_FORMAT" != "table" && "$BULK_FORMAT" != "json" ]]; then
    log_fail "--format must be one of: table, json"
    exit "$EXIT_CONFIG_ERROR"
  fi
}

bulk_load_config() {
  if [[ ! -f "$CONFIG_PATH" ]]; then
    log_fail "config not found: $CONFIG_PATH"
    exit "$EXIT_CONFIG_ERROR"
  fi

  log_info "reading config: $CONFIG_PATH"
  ALLOW_EMPTY_REPO=true
  parse_config

  if [[ -z "$ORG" && -n "$REPOS_OWNER" ]]; then
    ORG="$REPOS_OWNER"
  fi

  validate_config
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
    "create or update configured branches" \
    "apply or update rulesets" \
    "generate or update repository files" \
    "inject configured templates" \
    "add configured collaborators"

  log_ok "bulk dry run complete — no changes made"
}

bulk_target_owner_repo() {
  local target="$1"
  local owner repo

  if [[ "$target" == */* ]]; then
    owner="${target%%/*}"
    repo="${target#*/}"
  else
    owner="$ORG"
    repo="$target"
  fi

  if [[ -z "$owner" || -z "$repo" ]]; then
    log_fail "invalid bulk repo target: $target"
    return "$EXIT_CONFIG_ERROR"
  fi

  printf "%s\t%s\n" "$owner" "$repo"
}

bulk_report_init() {
  BULK_REPORT='[]'
}

bulk_report_add() {
  local repo="$1"
  local status="$2"
  local message="$3"

  BULK_REPORT=$(echo "$BULK_REPORT" | jq \
    --arg repo "$repo" \
    --arg status "$status" \
    --arg message "$message" \
    '. + [{repo: $repo, status: $status, message: $message}]')
}

bulk_report_print() {
  local total passed failed skipped

  total=$(echo "$BULK_REPORT" | jq 'length')
  passed=$(echo "$BULK_REPORT" | jq '[.[] | select(.status == "passed")] | length')
  failed=$(echo "$BULK_REPORT" | jq '[.[] | select(.status == "failed")] | length')
  skipped=$(echo "$BULK_REPORT" | jq '[.[] | select(.status == "skipped")] | length')

  if [[ "$BULK_FORMAT" == "json" ]]; then
    jq -n \
      --argjson total "$total" \
      --argjson passed "$passed" \
      --argjson failed "$failed" \
      --argjson skipped "$skipped" \
      --argjson repos "$BULK_REPORT" \
      '{summary: {total: $total, passed: $passed, failed: $failed, skipped: $skipped}, repos: $repos}'
    return
  fi

  log_info "bulk summary: $passed passed, $failed failed, $skipped skipped, $total total"
  echo "$BULK_REPORT" | jq -r '.[] | [.status, .repo, .message] | @tsv' \
    | while IFS=$'\t' read -r status repo message; do
      printf "  %-7s %-45s %s\n" "$status" "$repo" "$message"
    done
}

bulk_enforce_one() {
  local target="$1"
  local target_owner target_repo original_org original_repo previous_dir repo_dir

  IFS=$'\t' read -r target_owner target_repo < <(bulk_target_owner_repo "$target")
  original_org="$ORG"
  original_repo="$REPO_NAME"
  previous_dir="$PWD"

  ORG="$target_owner"
  REPO_NAME="$target_repo"

  log_info "bulk enforce: $ORG/$REPO_NAME"

  repo_dir=$(mktemp -d)
  trap 'rm -rf "$repo_dir"' EXIT

  if ! gh repo clone "$ORG/$REPO_NAME" "$repo_dir" &>/dev/null; then
    log_fail "failed to clone repo: $ORG/$REPO_NAME"
    ORG="$original_org"
    REPO_NAME="$original_repo"
    return "$EXIT_GITHUB_ERROR"
  fi

  cd "$repo_dir" || return "$EXIT_FS_ERROR"

  update_repo_settings
  ensure_branches
  generate_files
  inject_templates

  git checkout "$DEFAULT_BRANCH" --quiet 2>/dev/null || git checkout -b "$DEFAULT_BRANCH" --quiet
  git add -A
  if git diff --cached --quiet; then
    log_skip "$ORG/$REPO_NAME: no file changes to commit"
  else
    git commit -m "Enforce config with git-sentinel" --quiet
    git push origin "$DEFAULT_BRANCH" --quiet
    log_ok "$ORG/$REPO_NAME: pushed to $DEFAULT_BRANCH"
    sync_non_default_branches
  fi

  apply_rulesets
  add_collaborators

  cd "$previous_dir" || return "$EXIT_FS_ERROR"

  ORG="$original_org"
  REPO_NAME="$original_repo"
}

bulk_enforce() {
  bulk_validate
  check_dependencies
  if [[ "$DRY_RUN" != true || "$BULK_ALL" == true ]]; then
    authenticate
  fi
  bulk_load_config

  local repos count failed=0 target full_name message
  local target_owner target_repo skipped_target skipped_owner skipped_repo
  if [[ "$BULK_ALL" == true ]]; then
    repos=$(bulk_repos_from_discovery)
  else
    repos=$(bulk_repos_from_file)
  fi

  count=$(echo "$repos" | jq 'length')
  log_info "bulk enforce: $count repo(s) selected"

  if [[ "$DRY_RUN" == true ]]; then
    bulk_print_plan "$repos"
    return
  fi

  bulk_report_init

  while IFS= read -r target; do
    IFS=$'\t' read -r target_owner target_repo < <(bulk_target_owner_repo "$target")
    full_name="$target_owner/$target_repo"

    if ( bulk_enforce_one "$target" ); then
      bulk_report_add "$full_name" "passed" "enforced"
    else
      message="enforce failed"
      log_fail "bulk enforce failed: $target"
      bulk_report_add "$full_name" "failed" "$message"
      failed=$((failed + 1))

      if [[ "$BULK_CONTINUE_ON_ERROR" != true ]]; then
        while IFS= read -r skipped_target; do
          [[ -n "$skipped_target" ]] || continue
          IFS=$'\t' read -r skipped_owner skipped_repo < <(bulk_target_owner_repo "$skipped_target")
          bulk_report_add "$skipped_owner/$skipped_repo" "skipped" "not attempted after failure"
        done < <(echo "$repos" | jq -r --arg target "$target" '
          (index($target) + 1) as $start | .[$start:][]?
        ')
        break
      fi
    fi
  done < <(echo "$repos" | jq -r '.[]')

  bulk_report_print

  if [[ "$failed" -gt 0 ]]; then
    log_fail "bulk enforce completed with $failed failure(s)"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "bulk enforce complete"
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
    bulk_load_config
  else
    log_warn "config not found: $CONFIG_PATH"
    log_warn "bulk plan will show repo selection only"
  fi

  bulk_print_plan "$repos"
}
