#!/usr/bin/env bash
# branches.sh — branch creation and management
# Requires: git, gh, log.sh, config.sh (sourced before this)

ensure_branches() {
  # Ensure at least one commit exists (empty repos have no HEAD)
  if ! git rev-parse HEAD &>/dev/null; then
    git commit --allow-empty -m "Initial commit" --quiet
  fi

  for branch in ${BRANCHES[@]+"${BRANCHES[@]}"}; do
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

  if ! gh_api --method PATCH "/repos/$ORG/$REPO_NAME" \
    -f default_branch="$DEFAULT_BRANCH" &>/dev/null; then
    log_fail "failed to set default branch: $DEFAULT_BRANCH"
    exit "$EXIT_GITHUB_ERROR"
  fi

  log_ok "default branch set: $DEFAULT_BRANCH"
}

sync_non_default_branches() {
  local branch

  for branch in ${BRANCHES[@]+"${BRANCHES[@]}"}; do
    if [[ "$branch" == "$DEFAULT_BRANCH" ]]; then
      continue
    fi

    git branch -f "$branch" "$DEFAULT_BRANCH" &>/dev/null
    git push origin "$branch" --quiet
    log_ok "synced $branch to $DEFAULT_BRANCH"
  done
}
