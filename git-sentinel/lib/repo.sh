#!/usr/bin/env bash
# repo.sh — repo creation and update
# Requires: gh, git, log.sh, config.sh (sourced before this)

create_repo() {
  # Fail if repo already exists
  if gh repo view "$ORG/$REPO_NAME" &>/dev/null; then
    log_fail "repo already exists: $ORG/$REPO_NAME"
    log_fail "use 'git-sentinel enforce' to update an existing repo"
    exit "$EXIT_GITHUB_ERROR"
  fi

  local cmd=(gh repo create "$ORG/$REPO_NAME" "--$VISIBILITY" --description "$DESCRIPTION")

  [[ -n "$LICENSE" ]] && cmd+=(--license "$LICENSE")

  if ! "${cmd[@]}" &>/dev/null; then
    log_fail "failed to create repo: $ORG/$REPO_NAME"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "created repo: $ORG/$REPO_NAME ($VISIBILITY)"

  # Set delete_branch_on_merge (-F for boolean/typed value)
  if ! gh_api --method PATCH "/repos/$ORG/$REPO_NAME" \
    -F delete_branch_on_merge="$DELETE_BRANCH_ON_MERGE" &>/dev/null; then
    log_fail "failed to update repo settings: $ORG/$REPO_NAME"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "repo settings updated: $ORG/$REPO_NAME"

  # Clone into temp directory to work in it
  WORK_DIR=$(mktemp -d)
  if ! gh repo clone "$ORG/$REPO_NAME" "$WORK_DIR" &>/dev/null; then
    log_fail "failed to clone repo: $ORG/$REPO_NAME"
    exit "$EXIT_GITHUB_ERROR"
  fi

  cd "$WORK_DIR" || exit "$EXIT_FS_ERROR"
  log_ok "cloned repo into temp directory"
}

update_repo() {
  # Verify repo exists
  if ! gh repo view "$ORG/$REPO_NAME" &>/dev/null; then
    log_fail "repo does not exist: $ORG/$REPO_NAME"
    log_fail "use 'git-sentinel init' to create a new repo"
    exit "$EXIT_GITHUB_ERROR"
  fi

  # Clone if not already in the repo
  if ! git rev-parse --git-dir &>/dev/null; then
    WORK_DIR=$(mktemp -d)
    if ! gh repo clone "$ORG/$REPO_NAME" "$WORK_DIR" &>/dev/null; then
      log_fail "failed to clone repo: $ORG/$REPO_NAME"
      exit "$EXIT_GITHUB_ERROR"
    fi
    cd "$WORK_DIR" || exit "$EXIT_FS_ERROR"
    log_ok "cloned repo into temp directory"
  fi

  # Set delete_branch_on_merge (-F for boolean/typed value)
  if ! gh_api --method PATCH "/repos/$ORG/$REPO_NAME" \
    -F delete_branch_on_merge="$DELETE_BRANCH_ON_MERGE" &>/dev/null; then
    log_fail "failed to update repo settings: $ORG/$REPO_NAME"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "repo settings updated: $ORG/$REPO_NAME"
}
