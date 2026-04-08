#!/usr/bin/env bash
# repo.sh — repo creation and update
# Requires: gh, git, log.sh, config.sh (sourced before this)

# Update repo settings — non-fatal so a partial init doesn't strand the user.
# Settings are re-attempted on every enforce run.
update_repo_settings() {
  if gh_api --method PATCH "/repos/$ORG/$REPO_NAME" \
    -F delete_branch_on_merge="$DELETE_BRANCH_ON_MERGE" &>/dev/null; then
    log_ok "repo settings updated: $ORG/$REPO_NAME"
  else
    log_warn "failed to update repo settings (will retry on next enforce)"
  fi
}

create_repo() {
  # Fail if repo already exists
  if gh repo view "$ORG/$REPO_NAME" &>/dev/null; then
    log_fail "repo already exists: $ORG/$REPO_NAME"
    log_fail "use 'git-sentinel enforce' to update an existing repo"
    exit "$EXIT_GITHUB_ERROR"
  fi

  # Require cwd basename to match the configured repo name so we can init in place.
  local cwd_name
  cwd_name=$(basename "$PWD")
  if [[ "$cwd_name" != "$REPO_NAME" ]]; then
    log_fail "cwd '$cwd_name' does not match repo '$REPO_NAME'"
    log_fail "create and cd into a directory named '$REPO_NAME', then re-run init"
    exit "$EXIT_FS_ERROR"
  fi

  if [[ -d .git ]]; then
    log_fail "directory is already a git repo: $PWD"
    log_fail "remove .git/ or use 'git-sentinel enforce' instead"
    exit "$EXIT_FS_ERROR"
  fi

  # Create empty repo on GitHub. We deliberately do NOT pass --license: we
  # generate LICENSE locally so the in-place push isn't blocked by an
  # already-initialized remote.
  if ! gh repo create "$ORG/$REPO_NAME" "--$VISIBILITY" --description "$DESCRIPTION" &>/dev/null; then
    log_fail "failed to create repo: $ORG/$REPO_NAME"
    exit "$EXIT_GITHUB_ERROR"
  fi
  log_ok "created repo: $ORG/$REPO_NAME ($VISIBILITY)"

  update_repo_settings

  # Initialize git in place
  git init -b main &>/dev/null
  git remote add origin "https://github.com/$ORG/$REPO_NAME.git" &>/dev/null
  log_ok "git initialized in place: $PWD"
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

  update_repo_settings
}
