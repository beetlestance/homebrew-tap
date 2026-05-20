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
  local ruleset name target

  for ruleset in "$ROOT_DIR"/samples/*/rulesets/*.json; do
    jq empty "$ruleset"

    name=$(jq -r '.name // ""' "$ruleset")
    target=$(jq -r '.target // ""' "$ruleset")

    [[ -n "$name" ]] || fail "ruleset name required: $ruleset"
    [[ "$target" == "branch" ]] || fail "ruleset target must be branch: $ruleset"

    pass "ruleset fixture: ${ruleset#$ROOT_DIR/}"
  done
}

test_sample_dry_runs() {
  "$BIN" enforce --dry-run --config "$ROOT_DIR/samples/public/sentinel.yml" >/tmp/git-sentinel-public-dry-run.out
  assert_contains /tmp/git-sentinel-public-dry-run.out "ruleset JSON files to apply" "public sample dry-run uses ruleset JSON"

  "$BIN" enforce --dry-run --config "$ROOT_DIR/samples/private/sentinel.yml" >/tmp/git-sentinel-private-dry-run.out
  assert_contains /tmp/git-sentinel-private-dry-run.out "ruleset JSON files to apply" "private sample dry-run uses ruleset JSON"
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

main() {
  test_shell_syntax
  test_ruleset_fixtures
  test_sample_dry_runs
  test_bulk_dry_run_without_repo_field
  test_generated_files
  test_formula_rewrite_script
  pass "all tests passed"
}

main "$@"
