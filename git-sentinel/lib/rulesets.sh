#!/usr/bin/env bash
# rulesets.sh — GitHub Rulesets creation and enforcement
# Requires: gh, jq, log.sh (sourced before this)
# Expects: ORG, REPO_NAME, REQUIRED_REVIEWS, REQUIRE_CODE_OWNER_REVIEW,
#          REQUIRE_STATUS_CHECKS set by config.sh

resolve_bypass_actors() {
  local actors="[]"
  local user user_id team team_id app app_id

  for user in ${BYPASS_USERS[@]+"${BYPASS_USERS[@]}"}; do
    user_id=$(gh_api "/users/$user" --jq '.id' 2>/dev/null) || {
      log_fail "failed to resolve bypass user: $user"
      return "$EXIT_GITHUB_ERROR"
    }
    actors=$(echo "$actors" | jq \
      --argjson id "$user_id" \
      '. + [{ actor_id: $id, actor_type: "User", bypass_mode: "always" }]')
  done

  for team in ${BYPASS_TEAMS[@]+"${BYPASS_TEAMS[@]}"}; do
    team_id=$(gh_api "/orgs/$ORG/teams/$team" --jq '.id' 2>/dev/null) || {
      log_fail "failed to resolve bypass team: $team"
      return "$EXIT_GITHUB_ERROR"
    }
    actors=$(echo "$actors" | jq \
      --argjson id "$team_id" \
      '. + [{ actor_id: $id, actor_type: "Team", bypass_mode: "always" }]')
  done

  for app in ${BYPASS_APPS[@]+"${BYPASS_APPS[@]}"}; do
    app_id=$(gh_api "/apps/$app" --jq '.id' 2>/dev/null) || {
      log_fail "failed to resolve bypass app: $app"
      return "$EXIT_GITHUB_ERROR"
    }
    actors=$(echo "$actors" | jq \
      --argjson id "$app_id" \
      '. + [{ actor_id: $id, actor_type: "Integration", bypass_mode: "always" }]')
  done

  if [[ "$actors" == "[]" ]]; then
    local user_id
    user_id=$(gh_api "/user" --jq '.id' 2>/dev/null) || user_id=""
    if [[ -n "$user_id" ]]; then
      actors=$(jq -n --argjson id "$user_id" \
        '[{ actor_id: $id, actor_type: "User", bypass_mode: "always" }]')
      log_warn "no bypass_actors configured; defaulting bypass actor to current user"
    fi
  fi

  echo "$actors"
}

rulesets_api_error_message() {
  local error="$1"

  if [[ "$error" == *"Upgrade to GitHub Pro"* ]]; then
    echo "private repo rulesets require GitHub Pro/Team/Enterprise or public visibility"
  else
    echo "$error"
  fi
}

rulesets_api_available() {
  local error

  if gh_api "/repos/$ORG/$REPO_NAME/rulesets" >/dev/null 2>/tmp/git-sentinel-rulesets-error; then
    rm -f /tmp/git-sentinel-rulesets-error
    return 0
  fi

  error=$(cat /tmp/git-sentinel-rulesets-error 2>/dev/null || true)
  rm -f /tmp/git-sentinel-rulesets-error
  log_skip "rulesets API: $ORG/$REPO_NAME ($(rulesets_api_error_message "$error"))"
  return 1
}

rulesets_api_apply() {
  local action="$1"
  local name="$2"
  local endpoint="$3"
  local payload="$4"
  local error_file
  error_file=$(mktemp)

  if echo "$payload" | gh_api \
    --method "$action" \
    -H "Accept: application/vnd.github+json" \
    "$endpoint" \
    --input - > /dev/null 2>"$error_file"; then
    rm -f "$error_file"
    return 0
  fi

  local error
  error=$(cat "$error_file")
  rm -f "$error_file"
  log_fail "failed to apply ruleset $name: $(rulesets_api_error_message "$error")"
  return "$EXIT_GITHUB_ERROR"
}

create_or_update_ruleset() {
  local name="$1"
  local branch_pattern="$2"
  local required_reviews="$3"
  local merge_methods="$4"
  local code_owner_review="$5"

  local dismiss_stale="true"
  if [[ "$required_reviews" -eq 0 ]]; then
    dismiss_stale="false"
  fi

  local bypass_actors
  bypass_actors=$(resolve_bypass_actors)

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg branch "$branch_pattern" \
    --argjson reviews "$required_reviews" \
    --argjson dismiss "$dismiss_stale" \
    --argjson code_owner "$code_owner_review" \
    --argjson bypass_actors "$bypass_actors" \
    --argjson merge_methods "$merge_methods" \
    '{
      name: $name,
      target: "branch",
      enforcement: "active",
      conditions: { ref_name: { include: [$branch], exclude: [] } },
      rules: [
        { type: "deletion" },
        { type: "non_fast_forward" },
        { type: "pull_request", parameters: {
          required_approving_review_count: $reviews,
          dismiss_stale_reviews_on_push: $dismiss,
          require_code_owner_review: $code_owner,
          require_last_push_approval: false,
          required_review_thread_resolution: false,
          allowed_merge_methods: $merge_methods
        }},
        { type: "required_linear_history" }
      ],
      bypass_actors: $bypass_actors
    }')

  # The rulesets API normally returns an array, but on errors or unexpected
  # shapes (e.g. an error object) it can return something else. Guard the jq
  # iteration so we don't blow up with "Cannot index string with string".
  local existing
  existing=$(gh_api "/repos/$ORG/$REPO_NAME/rulesets" 2>/dev/null \
    | jq -r --arg name "$name" 'if type=="array" then (.[] | select(.name == $name)) else empty end')

  if [[ -n "$existing" ]]; then
    local ruleset_id
    ruleset_id=$(echo "$existing" | jq -r '.id')

    rulesets_api_apply PUT "$name" "/repos/$ORG/$REPO_NAME/rulesets/$ruleset_id" "$payload" \
      || { log_fail "failed to update ruleset: $name"; return "$EXIT_GITHUB_ERROR"; }

    log_ok "ruleset updated: $name"
  else
    rulesets_api_apply POST "$name" "/repos/$ORG/$REPO_NAME/rulesets" "$payload" \
      || { log_fail "failed to create ruleset: $name"; return "$EXIT_GITHUB_ERROR"; }

    log_ok "ruleset applied: $name"
  fi
}

create_or_update_ruleset_payload() {
  local ruleset_path="$1"
  local name="$2"
  local payload="$3"

  local existing_id
  existing_id=$(gh_api "/repos/$ORG/$REPO_NAME/rulesets" 2>/dev/null \
    | jq -r --arg name "$name" 'if type=="array" then (.[] | select(.name == $name) | .id) else empty end')

  if [[ -n "$existing_id" ]]; then
    rulesets_api_apply PUT "$name" "/repos/$ORG/$REPO_NAME/rulesets/$existing_id" "$payload" \
      || { log_fail "failed to update ruleset from $ruleset_path"; return "$EXIT_GITHUB_ERROR"; }

    log_ok "ruleset updated from JSON: $name"
  else
    rulesets_api_apply POST "$name" "/repos/$ORG/$REPO_NAME/rulesets" "$payload" \
      || { log_fail "failed to create ruleset from $ruleset_path"; return "$EXIT_GITHUB_ERROR"; }

    log_ok "ruleset applied from JSON: $name"
  fi
}

apply_ruleset_payloads() {
  local ruleset_path name payload

  for ruleset_path in ${RULESET_PATHS[@]+"${RULESET_PATHS[@]}"}; do
    name=$(jq -r '.name' "$ruleset_path")
    payload=$(jq -c '.' "$ruleset_path")
    create_or_update_ruleset_payload "$ruleset_path" "$name" "$payload"
  done
}

apply_rulesets() {
  if ! rulesets_api_available; then
    return 0
  fi

  if [[ "${#RULESET_PATHS[@]}" -gt 0 ]]; then
    apply_ruleset_payloads
    return
  fi

  local branch
  for branch in ${BRANCHES[@]+"${BRANCHES[@]}"}; do
    if [[ "$branch" == "$DEFAULT_BRANCH" ]]; then
      create_or_update_ruleset "protect-$branch" "refs/heads/$branch" 0 '["squash"]' false
    else
      create_or_update_ruleset "protect-$branch" "refs/heads/$branch" "$REQUIRED_REVIEWS" '["merge","rebase"]' "$REQUIRE_CODE_OWNER_REVIEW"
    fi
  done

}
