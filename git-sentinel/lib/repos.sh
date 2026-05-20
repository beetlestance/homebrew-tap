#!/usr/bin/env bash
# repos.sh — repository discovery commands
# Requires: gh, jq, yq, log.sh, github.sh (sourced before this)

repos_usage() {
  cat <<EOF
Usage: git-sentinel repos list (--org <org> | --user <user>) [options]

Options:
  --org <org>                 List repositories under an organization
  --user <user>               List repositories under a personal account
  --format <table|json|yaml>  Output format (default: table)
  --visibility <all|public|private>
                              Filter by visibility (default: all)
  --archived <all|true|false> Filter by archived status (default: false)
EOF
}

repos_list_validate() {
  if [[ "$REPOS_OWNER_TYPE" != "org" && "$REPOS_OWNER_TYPE" != "user" ]]; then
    log_fail "repos list requires --org <org> or --user <user>"
    repos_usage
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$REPOS_FORMAT" != "table" && "$REPOS_FORMAT" != "json" && "$REPOS_FORMAT" != "yaml" ]]; then
    log_fail "--format must be one of: table, json, yaml"
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$REPOS_VISIBILITY" != "all" && "$REPOS_VISIBILITY" != "public" && "$REPOS_VISIBILITY" != "private" ]]; then
    log_fail "--visibility must be one of: all, public, private"
    exit "$EXIT_CONFIG_ERROR"
  fi

  if [[ "$REPOS_ARCHIVED" != "all" && "$REPOS_ARCHIVED" != "true" && "$REPOS_ARCHIVED" != "false" ]]; then
    log_fail "--archived must be one of: all, true, false"
    exit "$EXIT_CONFIG_ERROR"
  fi
}

repos_list_fetch() {
  local endpoint
  if [[ "$REPOS_OWNER_TYPE" == "org" ]]; then
    endpoint="/orgs/$REPOS_OWNER/repos?per_page=100&type=all"
  else
    endpoint="/users/$REPOS_OWNER/repos?per_page=100&type=owner"
  fi

  gh_api --paginate "$endpoint" --jq '.[]' | jq -s \
    --arg visibility "$REPOS_VISIBILITY" \
    --arg archived "$REPOS_ARCHIVED" \
    'map({
      name,
      full_name,
      owner: .owner.login,
      visibility,
      private,
      archived,
      default_branch,
      language,
      pushed_at,
      html_url
    })
    | map(select($visibility == "all" or .visibility == $visibility))
    | map(select($archived == "all" or (.archived | tostring) == $archived))
    | sort_by(.full_name)'
}

repos_list_print_table() {
  local repos="$1"

  printf "%-42s %-8s %-8s %-18s %-14s %s\n" "REPOSITORY" "VIS" "ARCHIVE" "DEFAULT" "LANGUAGE" "PUSHED"
  echo "$repos" | jq -r '.[] | [
    .full_name,
    .visibility,
    (.archived | tostring),
    (.default_branch // "-"),
    (.language // "-"),
    (.pushed_at // "-")
  ] | @tsv' | while IFS=$'\t' read -r full_name visibility archived default_branch language pushed_at; do
    printf "%-42s %-8s %-8s %-18s %-14s %s\n" \
      "$full_name" "$visibility" "$archived" "$default_branch" "$language" "$pushed_at"
  done
}

repos_list() {
  repos_list_validate

  check_dependencies
  authenticate

  local repos
  repos=$(repos_list_fetch)

  case "$REPOS_FORMAT" in
    table) repos_list_print_table "$repos" ;;
    json)  echo "$repos" ;;
    yaml)  echo "$repos" | yq -P -o=yaml '.' ;;
  esac
}
