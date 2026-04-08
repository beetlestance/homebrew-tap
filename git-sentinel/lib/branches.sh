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
    if git ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
      log_skip "branch: $branch (already on remote)"
      continue
    fi

    # Create local branch if it doesn't exist yet
    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
      git branch "$branch" &>/dev/null
    fi

    git push -u origin "$branch" &>/dev/null || {
      log_fail "failed to push branch: $branch"
      exit "$EXIT_GITHUB_ERROR"
    }
    log_ok "branch created: $branch"
  done

  # Set develop as the default branch
  if ! gh_api --method PATCH "/repos/$ORG/$REPO_NAME" \
    -f default_branch="develop" &>/dev/null; then
    log_fail "failed to set default branch: develop"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "default branch set: develop"
}
