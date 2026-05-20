# Changelog

All notable git-sentinel changes are documented here.

## Unreleased

No unreleased changes yet.

## git-sentinel v3.0.0 - 2026-05-20

### Added

- Added dry-run planning for `init` and `enforce`.
- Added `repos list` for discovering repositories under an organization or user.
- Added `bulk plan` and `bulk enforce` for selected repositories or full owner scopes.
- Added `diff` to compare GitHub repo state against `sentinel.yml`.
- Added `doctor` to check local dependencies, GitHub auth, config, and repo access.
- Added configurable `branches:` and `default_branch:`.
- Added raw GitHub Rulesets JSON payload support through `rulesets:`.
- Added explicit bypass actor support in generated ruleset fallback mode.
- Added public and private sample policies with ruleset JSON payloads.
- Added a guided Codex skill for generating `sentinel.yml` and ruleset JSON.
- Added fixture tests, CI coverage, and a tested release formula rewrite script.

### Changed

- Improved `diff` output for ruleset drift, including enforcement, branch refs,
  bypass actors, rule types, status checks, and pull request policy.
- Improved bulk output with passed, failed, and skipped summaries plus
  `--format json` for CI and audit logs.
- Limited ruleset JSON validation to transport basics: file exists, valid JSON,
  and a `name` field. GitHub remains the semantic validator.
- Updated recovery docs for interrupted `init` runs and matching local git
  repositories.

### Fixed

- Handled empty optional config arrays on macOS Bash 3.2.
- Made `doctor`, `diff`, and `enforce` gracefully skip unavailable private
  repository rulesets when the GitHub plan does not support them.
- Made `init` recover when the local git repo already points at the configured
  GitHub origin.
- Made `doctor --config` skip missing repositories during pre-init checks
  instead of failing.

## git-sentinel v2.0.1 - 2026-05-20

### Changed

- Bumped the git-sentinel version to `v2.0.1`.
- Prepared the release workflow for atomic Homebrew formula updates and release
  publishing from the same tap repository.

## git-sentinel v2.0.0 - 2026-04-08

### Added

- Added in-place `init`, so git-sentinel initializes the current directory
  instead of using a temporary clone.
- Added develop-first setup, pushing the configured default branch first and
  syncing the release branch from it.
- Added generated `.gitignore` handling during repository setup.

### Changed

- Updated branch setup, repo initialization, ruleset application, and README
  guidance for the in-place init flow.
- Improved repo hygiene around generated files and branch synchronization.

## git-sentinel v1.0.3 - 2026-04-08

### Fixed

- Fixed `git-sentinel schema` when installed through Homebrew by moving the
  example schema into the installed library path.

## git-sentinel v1.0.2 - 2026-03-23

### Changed

- Bumped the git-sentinel version to `v1.0.2`.
- Refined README install and usage guidance.

## git-sentinel v1.0.1 - 2026-03-23

### Fixed

- Fixed the Homebrew formula so stable installs use released archives while
  `--HEAD` remains available for the moving development branch.
- Updated the main branch ruleset fallback to allow rebase merges.

## git-sentinel v1.0.0 - 2026-03-22

### Added

- Added the first released Homebrew install flow for git-sentinel.
- Added release automation for publishing git-sentinel from this tap.
- Added initial README documentation for installing and running the tool.
