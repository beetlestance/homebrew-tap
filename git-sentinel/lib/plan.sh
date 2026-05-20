#!/usr/bin/env bash
# plan.sh — dry-run planning output
# Requires: log.sh, config.sh (sourced before this)

plan_list_items() {
  local label="$1"
  shift

  if [[ "$#" -eq 0 ]]; then
    log_skip "$label: none"
    return
  fi

  log_info "$label:"
  local item
  for item in "$@"; do
    echo "  - $item"
  done
}

plan_files() {
  local readme_source
  if [[ -n "$README_PATH" ]]; then
    readme_source="README.md from $README_PATH"
  else
    readme_source="README.md generated from repo name and description"
  fi

  local files=(
    ".gitattributes"
    ".gitignore"
    "$readme_source"
  )

  if [[ -n "$LICENSE" ]]; then
    files+=("LICENSE from GitHub license key '$LICENSE'")
  fi

  files+=(
    "GIT_REFERENCE.md"
    ".github/PULL_REQUEST_TEMPLATE.md"
  )

  plan_list_items "files to generate or update" \
    "${files[@]}"

  plan_list_items "templates to inject" "${TEMPLATES[@]}"
}

plan_rulesets() {
  if [[ "${#RULESET_PATHS[@]}" -gt 0 ]]; then
    plan_list_items "ruleset JSON files to apply" "${RULESET_PATHS[@]}"
    return
  fi

  plan_list_items "rulesets to apply" \
    "protect-main: PR required, $REQUIRED_REVIEWS approving review(s), code owner review: $REQUIRE_CODE_OWNER_REVIEW, merge/rebase allowed, linear history" \
    "protect-develop: PR required, 0 approving reviews, squash merge only, linear history"
  plan_list_items "bypass users" "${BYPASS_USERS[@]}"
  plan_list_items "bypass teams" "${BYPASS_TEAMS[@]}"
  plan_list_items "bypass apps" "${BYPASS_APPS[@]}"
}

plan_init() {
  log_info "dry run: init $ORG/$REPO_NAME"
  plan_list_items "repository actions" \
    "create GitHub repo $ORG/$REPO_NAME ($VISIBILITY)" \
    "set delete_branch_on_merge to $DELETE_BRANCH_ON_MERGE" \
    "initialize current directory as git repo" \
    "add origin https://github.com/$ORG/$REPO_NAME.git"
  plan_list_items "branch actions" \
    "create or push main" \
    "create or push develop" \
    "set develop as default branch" \
    "commit generated files to develop" \
    "fast-forward main to develop"
  plan_files
  plan_rulesets
  plan_list_items "collaborators to add" "${COLLABORATORS[@]}"
  plan_list_items "cleanup actions" "remove $CONFIG_PATH from working tree"
  log_ok "dry run complete — no changes made"
}

plan_enforce() {
  log_info "dry run: enforce $ORG/$REPO_NAME"
  plan_list_items "repository actions" \
    "verify GitHub repo $ORG/$REPO_NAME exists" \
    "clone repo to a temp directory if not already inside a git repo" \
    "set delete_branch_on_merge to $DELETE_BRANCH_ON_MERGE"
  plan_list_items "branch actions" \
    "create or push main if missing" \
    "create or push develop if missing" \
    "set develop as default branch" \
    "commit generated changes to develop if needed" \
    "fast-forward main to develop if changes were committed"
  plan_files
  plan_rulesets
  plan_list_items "collaborators to add" "${COLLABORATORS[@]}"
  log_ok "dry run complete — no changes made"
}
