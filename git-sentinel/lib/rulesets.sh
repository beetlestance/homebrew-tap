#!/usr/bin/env bash
# rulesets.sh — GitHub Rulesets creation and enforcement
# Requires: gh, jq, log.sh (sourced before this)
# Expects: ORG, REPO_NAME, REQUIRED_REVIEWS, REQUIRE_CODE_OWNER_REVIEW,
#          REQUIRE_STATUS_CHECKS set by config.sh

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

  # Get current user's ID for bypass actor
  local user_id
  user_id=$(gh_api "/user" --jq '.id' 2>/dev/null) || user_id=""

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg branch "$branch_pattern" \
    --argjson reviews "$required_reviews" \
    --argjson dismiss "$dismiss_stale" \
    --argjson code_owner "$code_owner_review" \
    --argjson user_id "${user_id:-0}" \
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
      bypass_actors: [
        { actor_id: $user_id, actor_type: "User", bypass_mode: "always" }
      ]
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

    echo "$payload" | gh_api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      "/repos/$ORG/$REPO_NAME/rulesets/$ruleset_id" \
      --input - > /dev/null \
      || { log_fail "failed to update ruleset: $name"; return "$EXIT_GITHUB_ERROR"; }

    log_ok "ruleset updated: $name"
  else
    echo "$payload" | gh_api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      "/repos/$ORG/$REPO_NAME/rulesets" \
      --input - > /dev/null \
      || { log_fail "failed to create ruleset: $name"; return "$EXIT_GITHUB_ERROR"; }

    log_ok "ruleset applied: $name"
  fi
}

apply_rulesets() {
  # main: merge + rebase allowed (rebase enables ff push by bypass actors), no linear history
  create_or_update_ruleset "protect-main" "refs/heads/main" "$REQUIRED_REVIEWS" '["merge","rebase"]' "$REQUIRE_CODE_OWNER_REVIEW"

  # develop: squash merge only, 0 reviews, no code owner review
  create_or_update_ruleset "protect-develop" "refs/heads/develop" 0 '["squash"]' false
}
