#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BIN="$ROOT_DIR/bin/git-sentinel"
FORMULA_SCRIPT="$ROOT_DIR/scripts/update-formula.rb"

pass() {
  printf "ok: %s\n" "$1"
}

fail() {
  printf "fail: %s\n" "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -Fq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

test_shell_syntax() {
  bash -n "$BIN" "$ROOT_DIR"/lib/*.sh
  ruby -c "$FORMULA_SCRIPT" >/dev/null
  pass "shell syntax"
}

test_ruleset_fixtures() {
  local ruleset name

  for ruleset in "$ROOT_DIR"/samples/*/rulesets/*.json; do
    jq empty "$ruleset"

    name=$(jq -r '.name // ""' "$ruleset")

    [[ -n "$name" ]] || fail "ruleset name required: $ruleset"

    pass "ruleset fixture: ${ruleset#$ROOT_DIR/}"
  done
}

test_sample_dry_runs() {
  "$BIN" enforce --dry-run --config "$ROOT_DIR/samples/public/sentinel.yml" >/tmp/git-sentinel-public-dry-run.out
  assert_contains /tmp/git-sentinel-public-dry-run.out "ruleset JSON files to apply" "public sample dry-run uses ruleset JSON"

  "$BIN" enforce --dry-run --config "$ROOT_DIR/samples/private/sentinel.yml" >/tmp/git-sentinel-private-dry-run.out
  assert_contains /tmp/git-sentinel-private-dry-run.out "ruleset JSON files to apply" "private sample dry-run uses ruleset JSON"
}

test_unset_config_arrays() {
  (
    set -u
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/log.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/config.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/templates.sh"

    inject_templates
    [[ "${#TEMPLATES[@]}" -eq 0 ]]
    [[ "${#RULESET_PATHS[@]}" -eq 0 ]]
  )
  pass "unset config arrays are safe"
}

test_macos_bash_dry_run() {
  local config
  config="$ROOT_DIR/test/fixtures/macos-bash/sentinel.yml"

  (
    cd "$(dirname "$config")"
    /bin/bash "$BIN" init --dry-run --config "$config" >/tmp/git-sentinel-macos-bash.out
  )
  assert_contains /tmp/git-sentinel-macos-bash.out "dry run complete" "macOS bash dry-run handles empty arrays"
}

test_bulk_dry_run_without_repo_field() {
  local tmp_dir config repos output
  tmp_dir=$(mktemp -d)
  config="$tmp_dir/sentinel.yml"
  repos="$tmp_dir/repos.txt"
  output="$tmp_dir/bulk.out"

  cat > "$config" <<'YAML'
org: example-org
visibility: private
description: "Bulk policy template"
branches:
  - stable
  - trunk
default_branch: trunk
delete_branch_on_merge: true
YAML

  cat > "$repos" <<'EOF'
example-org/service-one
service-two
EOF

  "$BIN" bulk enforce --dry-run --repos "$repos" --config "$config" > "$output"
  assert_contains "$output" "config validated: example-org/<bulk-target>" "bulk config may omit repo"
  assert_contains "$output" "bulk dry run: 2 repo(s) selected" "bulk dry-run selects repos"

  rm -rf "$tmp_dir"
}

test_generated_files() {
  local tmp_dir config
  tmp_dir=$(mktemp -d)
  config="$tmp_dir/sentinel.yml"

  cat > "$config" <<'YAML'
org: example-org
repo: generated-fixture
visibility: private
description: "Generated file fixture"
branches:
  - stable
  - trunk
default_branch: trunk
delete_branch_on_merge: true
YAML

  (
    SCRIPT_DIR="$ROOT_DIR/bin"
    CONFIG_PATH="$config"

    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/log.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/config.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/files.sh"

    parse_config
    validate_config

    cd "$tmp_dir"
    generate_files
  ) >/tmp/git-sentinel-generated-files.out

  [[ -f "$tmp_dir/.gitattributes" ]] || fail "generated .gitattributes"
  [[ -f "$tmp_dir/.gitignore" ]] || fail "generated .gitignore"
  [[ -f "$tmp_dir/README.md" ]] || fail "generated README.md"
  [[ -f "$tmp_dir/GIT_REFERENCE.md" ]] || fail "generated GIT_REFERENCE.md"
  [[ -f "$tmp_dir/.github/PULL_REQUEST_TEMPLATE.md" ]] || fail "generated PR template"

  assert_contains "$tmp_dir/GIT_REFERENCE.md" "git checkout trunk" "git reference uses configured default branch"
  assert_contains "$tmp_dir/GIT_REFERENCE.md" '| `stable` | Production/release |' "git reference uses configured release branch"

  rm -rf "$tmp_dir"
}

test_formula_rewrite_script() {
  local tmp_dir formula
  tmp_dir=$(mktemp -d)
  formula="$tmp_dir/git-sentinel.rb"

  cp "$REPO_ROOT/Formula/git-sentinel.rb" "$formula"

  "$FORMULA_SCRIPT" \
    --formula "$formula" \
    --url "https://example.com/git-sentinel-v9.8.7.tar.gz" \
    --sha256 "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" \
    --version "9.8.7"

  assert_contains "$formula" '  url "https://example.com/git-sentinel-v9.8.7.tar.gz"' "formula rewrite updates url"
  assert_contains "$formula" '  sha256 "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' "formula rewrite updates sha256"
  assert_contains "$formula" '  version "9.8.7"' "formula rewrite updates version"
  assert_contains "$formula" '  head "https://github.com/beetlestance/homebrew-tap.git", branch: "develop"' "formula rewrite preserves head"

  rm -rf "$tmp_dir"
}

test_diff_ruleset_details() {
  local tmp_dir expected current output
  tmp_dir=$(mktemp -d)
  expected="$tmp_dir/expected.json"
  current="$tmp_dir/current.json"
  output="$tmp_dir/diff.out"

  cat > "$expected" <<'JSON'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [{"context": "ci/test", "integration_id": null}]
      }
    }
  ],
  "bypass_actors": [{"actor_id": 1, "actor_type": "User", "bypass_mode": "pull_request"}]
}
JSON

  cat > "$current" <<'JSON'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "evaluate",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/stable"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [{"context": "ci/lint", "integration_id": null}]
      }
    }
  ],
  "bypass_actors": [{"actor_id": 2, "actor_type": "Team", "bypass_mode": "always"}]
}
JSON

  (
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/log.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/diff.sh"
    diff_ruleset_details "protect-main" "$expected" "$current"
  ) >"$output" 2>&1

  assert_contains "$output" "ruleset protect-main enforcement differs" "diff reports ruleset enforcement drift"
  assert_contains "$output" "ruleset protect-main branch refs differs" "diff reports ruleset branch drift"
  assert_contains "$output" "ruleset protect-main bypass actors differs" "diff reports ruleset bypass drift"
  assert_contains "$output" "ruleset protect-main required status checks differs" "diff reports status check drift"

  rm -rf "$tmp_dir"
}

test_bulk_json_report() {
  local tmp_dir output
  tmp_dir=$(mktemp -d)
  output="$tmp_dir/report.json"

  (
    BULK_FORMAT="json"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/log.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/bulk.sh"

    bulk_report_init
    bulk_report_add "example-org/one" "passed" "enforced"
    bulk_report_add "example-org/two" "failed" "enforce failed"
    bulk_report_add "example-org/three" "skipped" "not attempted after failure"
    bulk_report_print
  ) > "$output"

  jq -e '
    .summary == {total: 3, passed: 1, failed: 1, skipped: 1}
    and (.repos | length == 3)
  ' "$output" >/dev/null
  pass "bulk json report"

  rm -rf "$tmp_dir"
}

test_guided_skill() {
  local skill="$ROOT_DIR/skills/repo-policy/SKILL.md"

  [[ -f "$skill" ]] || fail "guided skill exists"
  assert_contains "$skill" "name: git-sentinel-repo-policy" "guided skill has name"
  assert_contains "$skill" "description:" "guided skill has description"
  assert_contains "$skill" "sentinel.yml" "guided skill generates sentinel config"
  assert_contains "$skill" "rulesets/" "guided skill generates ruleset JSON"
  assert_contains "$skill" "GitHub owns that" "guided skill preserves ruleset validation boundary"
}

test_doctor_repo_checks() {
  local tmp_dir fake_bin output
  tmp_dir=$(mktemp -d)
  fake_bin="$tmp_dir/bin"
  output="$tmp_dir/doctor.out"
  mkdir -p "$fake_bin"

  cat > "$fake_bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "auth" && "$2" == "status" ]]; then
  exit 0
fi

if [[ "$1" == "repo" && "$2" == "view" ]]; then
  case "$3" in
    example-org/missing)
      exit 1
      ;;
    example-org/private-no-rulesets)
      printf '{"nameWithOwner":"example-org/private-no-rulesets","visibility":"PRIVATE"}\n'
      exit 0
      ;;
  esac
fi

if [[ "$1" == "api" && "$2" == "/repos/example-org/private-no-rulesets/rulesets" ]]; then
  printf 'gh: Upgrade to GitHub Pro or make this repository public to enable this feature. (HTTP 403)\n' >&2
  exit 1
fi

exit 1
SH
  chmod +x "$fake_bin/gh"

  (
    PATH="$fake_bin:$PATH"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/log.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/github.sh"
    # shellcheck source=/dev/null
    source "$ROOT_DIR/lib/doctor.sh"

    DOCTOR_FAILED=false
    doctor_check_auth
    doctor_check_repo_access "example-org" "missing"
    doctor_check_repo_access "example-org" "private-no-rulesets"
    [[ "$DOCTOR_FAILED" == false ]]
  ) >"$output" 2>&1

  assert_contains "$output" "repo access: example-org/missing (not found or inaccessible; ok before init)" "doctor skips missing repo"
  assert_contains "$output" "private repo rulesets require GitHub Pro/Team/Enterprise or public visibility" "doctor skips private ruleset plan limitation"

  rm -rf "$tmp_dir"
}

main() {
  test_shell_syntax
  test_ruleset_fixtures
  test_sample_dry_runs
  test_unset_config_arrays
  test_macos_bash_dry_run
  test_bulk_dry_run_without_repo_field
  test_generated_files
  test_formula_rewrite_script
  test_diff_ruleset_details
  test_bulk_json_report
  test_guided_skill
  test_doctor_repo_checks
  pass "all tests passed"
}

main "$@"
