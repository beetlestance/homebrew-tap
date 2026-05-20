#!/usr/bin/env bash
# diff.sh — compare desired config against current GitHub repo state
# Requires: gh, git, jq, yq, log.sh, github.sh, config.sh, files.sh

DIFF_HAS_DRIFT=false

diff_ok() {
  log_ok "$1"
}

diff_drift() {
  log_warn "drift: $1"
  DIFF_HAS_DRIFT=true
}

diff_current_repo() {
  gh_api "/repos/$ORG/$REPO_NAME"
}

diff_check_repo_settings() {
  local repo_json="$1"
  local current_visibility current_default current_delete

  current_visibility=$(echo "$repo_json" | jq -r 'if .private then "private" else "public" end')
  current_default=$(echo "$repo_json" | jq -r '.default_branch // ""')
  current_delete=$(echo "$repo_json" | jq -r '.delete_branch_on_merge // false')

  if [[ "$current_visibility" == "$VISIBILITY" ]]; then
    diff_ok "visibility matches: $VISIBILITY"
  else
    diff_drift "visibility is $current_visibility, expected $VISIBILITY"
  fi

  if [[ "$current_default" == "$DEFAULT_BRANCH" ]]; then
    diff_ok "default branch matches: $DEFAULT_BRANCH"
  else
    diff_drift "default branch is $current_default, expected $DEFAULT_BRANCH"
  fi

  if [[ "$current_delete" == "$DELETE_BRANCH_ON_MERGE" ]]; then
    diff_ok "delete_branch_on_merge matches: $DELETE_BRANCH_ON_MERGE"
  else
    diff_drift "delete_branch_on_merge is $current_delete, expected $DELETE_BRANCH_ON_MERGE"
  fi
}

diff_check_branches() {
  local remote_branches branch
  remote_branches=$(gh_api "/repos/$ORG/$REPO_NAME/branches?per_page=100" --paginate \
    | jq -r '.[].name')

  for branch in "${BRANCHES[@]}"; do
    if grep -Fxq "$branch" <<<"$remote_branches"; then
      diff_ok "branch exists: $branch"
    else
      diff_drift "missing branch: $branch"
    fi
  done
}

diff_normalize_ruleset() {
  jq -S '
    del(
      .id,
      .node_id,
      ._links,
      .created_at,
      .updated_at,
      .source,
      .source_type
    )
  ' "$1"
}

diff_check_json_rulesets() {
  local remote_list ruleset_path name id expected_file current_file
  remote_list=$(gh_api "/repos/$ORG/$REPO_NAME/rulesets")

  for ruleset_path in "${RULESET_PATHS[@]}"; do
    name=$(jq -r '.name' "$ruleset_path")
    id=$(echo "$remote_list" | jq -r --arg name "$name" \
      'if type=="array" then (.[] | select(.name == $name) | .id) else empty end')

    if [[ -z "$id" ]]; then
      diff_drift "missing ruleset: $name"
      continue
    fi

    expected_file=$(mktemp)
    current_file=$(mktemp)

    diff_normalize_ruleset "$ruleset_path" > "$expected_file"
    gh_api "/repos/$ORG/$REPO_NAME/rulesets/$id" \
      | jq -S 'del(.id,.node_id,._links,.created_at,.updated_at,.source,.source_type)' \
      > "$current_file"

    if cmp -s "$expected_file" "$current_file"; then
      diff_ok "ruleset matches: $name"
    else
      diff_drift "ruleset differs: $name"
    fi

    rm -f "$expected_file" "$current_file"
  done
}

diff_check_generated_rulesets() {
  local remote_list branch name
  remote_list=$(gh_api "/repos/$ORG/$REPO_NAME/rulesets")

  for branch in "${BRANCHES[@]}"; do
    name="protect-$branch"
    if echo "$remote_list" | jq -e --arg name "$name" \
      'if type=="array" then any(.[]; .name == $name) else false end' >/dev/null; then
      diff_ok "ruleset exists: $name"
    else
      diff_drift "missing generated ruleset: $name"
    fi
  done
}

diff_check_rulesets() {
  if [[ "${#RULESET_PATHS[@]}" -gt 0 ]]; then
    diff_check_json_rulesets
  else
    diff_check_generated_rulesets
  fi
}

diff_remote_file_hash() {
  local path="$1"
  local encoded_file decoded_file hash

  encoded_file=$(mktemp)
  decoded_file=$(mktemp)

  if ! gh_api "/repos/$ORG/$REPO_NAME/contents/$path?ref=$DEFAULT_BRANCH" --jq '.content' 2>/dev/null \
    | tr -d '\n' > "$encoded_file"; then
    rm -f "$encoded_file" "$decoded_file"
    return 1
  fi

  if ! base64 --decode < "$encoded_file" > "$decoded_file" 2>/dev/null; then
    if ! base64 -D < "$encoded_file" > "$decoded_file" 2>/dev/null; then
      rm -f "$encoded_file" "$decoded_file"
      return 1
    fi
  fi

  hash=$(shasum -a 256 "$decoded_file" | awk '{print $1}')
  rm -f "$encoded_file" "$decoded_file"

  echo "$hash"
}

diff_local_file_hash() {
  local path="$1"
  shasum -a 256 "$path" | awk '{print $1}'
}

diff_check_file() {
  local path="$1"
  local expected_hash current_hash

  if [[ ! -f "$path" ]]; then
    return
  fi

  expected_hash=$(diff_local_file_hash "$path")
  current_hash=$(diff_remote_file_hash "$path" || true)

  if [[ -z "$current_hash" ]]; then
    diff_drift "missing file on $DEFAULT_BRANCH: $path"
  elif [[ "$current_hash" == "$expected_hash" ]]; then
    diff_ok "file matches: $path"
  else
    diff_drift "file differs on $DEFAULT_BRANCH: $path"
  fi
}

diff_check_files() {
  local previous_dir desired_dir
  previous_dir="$PWD"
  desired_dir=$(mktemp -d)

  cd "$desired_dir" || exit "$EXIT_FS_ERROR"
  generate_files
  inject_templates

  while IFS= read -r path; do
    diff_check_file "$path"
  done < <(find . -type f | sed 's#^\./##' | sort)

  cd "$previous_dir" || exit "$EXIT_FS_ERROR"
  rm -rf "$desired_dir"
}

diff_check_collaborators() {
  local user

  if [[ "${#COLLABORATORS[@]}" -eq 0 ]]; then
    diff_ok "collaborators configured: none"
    return
  fi

  for user in "${COLLABORATORS[@]}"; do
    if gh_api "/repos/$ORG/$REPO_NAME/collaborators/$user/permission" >/dev/null 2>&1; then
      diff_ok "collaborator has access: $user"
    else
      diff_drift "collaborator missing or inaccessible: $user"
    fi
  done
}

sentinel_diff() {
  check_dependencies
  authenticate

  log_info "reading config: $CONFIG_PATH"
  parse_config
  validate_config

  local repo_json
  repo_json=$(diff_current_repo) || {
    log_fail "repo does not exist or is inaccessible: $ORG/$REPO_NAME"
    exit "$EXIT_GITHUB_ERROR"
  }

  log_info "checking repo settings"
  diff_check_repo_settings "$repo_json"

  log_info "checking branches"
  diff_check_branches

  log_info "checking rulesets"
  diff_check_rulesets

  log_info "checking generated files on $DEFAULT_BRANCH"
  diff_check_files

  log_info "checking collaborators"
  diff_check_collaborators

  if [[ "$DIFF_HAS_DRIFT" == true ]]; then
    log_fail "diff found drift"
    exit "$EXIT_CONFIG_ERROR"
  fi

  log_ok "diff passed — repo matches sentinel config"
}
