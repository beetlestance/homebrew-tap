#!/usr/bin/env bash
# branches.sh — branch creation and management
# Requires: git, gh, log.sh, config.sh (sourced before this)

ensure_branches() {
  local branches=("main" "develop")

  # Ensure at least one commit exists (empty repos have no HEAD)
  if ! git rev-parse HEAD &>/dev/null; then
    git commit --allow-empty -m "Initial commit" --quiet
  fi

  for branch in "${branches[@]}"; do
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
      log_skip "branch: $branch (already exists)"
    else
      git branch "$branch" &>/dev/null
      git push -u origin "$branch" &>/dev/null || {
        log_fail "failed to push branch: $branch"
        exit "$EXIT_GITHUB_ERROR"
      }
      log_ok "branch created: $branch"
    fi
  done

  # Set develop as the default branch
  if ! gh_api --method PATCH "/repos/$ORG/$REPO_NAME" \
    -f default_branch="develop" &>/dev/null; then
    log_fail "failed to set default branch: develop"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "default branch set: develop"
}
