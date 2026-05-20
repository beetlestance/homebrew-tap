# git-sentinel

Bash CLI for automated GitHub repo setup and ruleset enforcement.

One config file. One command. Consistent repos every time.

## Install

```bash
brew tap beetlestance/tap
brew install git-sentinel
```

Stable installs use the latest released formula in this tap. To install from
the moving `develop` branch instead:

```bash
brew install --HEAD git-sentinel
```

Or run directly:

```bash
git clone https://github.com/beetlestance/homebrew-tap.git
cd homebrew-tap/git-sentinel
bash bin/git-sentinel help
```

### Dependencies

| Tool | Purpose |
|---|---|
| [gh](https://cli.github.com/) | GitHub CLI — all API calls |
| [yq](https://github.com/mikefarah/yq) | YAML parsing |
| [jq](https://jqlang.github.io/jq/) | JSON for ruleset payloads |
| git | Branch operations |

## Quick Start

```bash
# Make a directory matching the repo name and cd in
mkdir my-repo && cd my-repo

# Scaffold a config (runtime-only — will be removed automatically after init)
git-sentinel schema > sentinel.yml
vim sentinel.yml      # set org, repo, etc.

# Create the GitHub repo and initialize this directory in place
git-sentinel init

# Or, on an existing repo: cd in and update
git-sentinel enforce
```

> `git-sentinel init` initializes the **current directory** as the working tree
> (no temp clones). The cwd's basename must match `repo:` in `sentinel.yml`.
> `sentinel.yml` is gitignored and removed from the working tree once init succeeds.

## Commands

| Command | What it does |
|---|---|
| `init` | Create a new repo from `sentinel.yml` |
| `enforce` | Apply/update rulesets and files on existing repo |
| `schema` | Print fully annotated `sentinel.yml` to stdout |
| `help` | Show usage |
| `version` | Show installed version |

Only flag: `--config <path>` (default: `./sentinel.yml`)

## What It Does

### On `init`

1. Creates the GitHub repo (public or private)
2. Initializes the current directory as a git repo in place (no temp clone)
3. Sets up `main` and `develop` branches, `develop` as default
4. Generates files: `.gitattributes`, `.gitignore`, `README.md`, `LICENSE`, `GIT_REFERENCE.md`, PR template
5. Injects user-provided templates (files or folders)
6. Commits to `develop` and fast-forwards `main` so both branches start at the same SHA
7. Applies rulesets (branch protection, merge rules, linear history)
8. Adds collaborators
9. Removes `sentinel.yml` from the working tree (it's runtime-only and gitignored)

### On `enforce`

Same as init but on an existing repo — updates rulesets, regenerates files, injects templates.

## sentinel.yml Reference

```yaml
# Required
org: beetlestance
repo: my-repo

# Optional — all have sensible defaults
visibility: private                # public or private (default: private)
description: "Short description"   # used in default README + GitHub metadata
required_reviews: 0                # approving reviews before merge into main
delete_branch_on_merge: true       # auto-delete feature branches after merge
require_code_owner_review: false   # require CODEOWNERS review

# Files
readme: ./README.md                # custom README path (omit for auto-generated)
license: gpl-3.0                   # any SPDX key GitHub supports (omit to skip)

# People
collaborators:
  - kamesh

# Templates — files or folders to inject into the repo
templates:
  - ./CLAUDE.md
  - ./company-templates/
```

Run `git-sentinel schema` for the full annotated reference.

## Rulesets

git-sentinel creates two rulesets via the GitHub Rulesets API:

### protect-main

| Rule | Setting |
|---|---|
| Direct push | Blocked |
| Force push | Blocked |
| Branch deletion | Blocked |
| Pull request required | Yes, reviews from config |
| Code owner review | From config |
| Allowed merge methods | Merge commit only |
| Linear history | Required |

### protect-develop

| Rule | Setting |
|---|---|
| Direct push | Blocked |
| Force push | Blocked |
| Branch deletion | Blocked |
| Pull request required | Yes, 0 reviews |
| Code owner review | No |
| Allowed merge methods | Squash merge only |
| Linear history | Required |

## Auto-Generated Files

| File | Purpose |
|---|---|
| `.gitattributes` | Normalize line endings (LF), mark binary files |
| `.gitignore` | OS files, editors, env, deps, build, logs |
| `README.md` | Title + description + links to LICENSE, GIT_REFERENCE, PR template |
| `LICENSE` | Fetched from GitHub's licenses API at runtime |
| `GIT_REFERENCE.md` | Branch strategy, merge rules, common commands, recovery guide |
| `.github/PULL_REQUEST_TEMPLATE.md` | What, Why, How, Testing, Checklist |

## FAQ

**"repo already exists" on init**
Use `git-sentinel enforce` to update an existing repo.

**"push declined due to repository rule violations"**
The rulesets are working. Changes to protected branches must go through PRs.

**yq/jq not found**
Install via: `brew install yq jq` (Mac), `scoop install yq jq` (Windows), `apt install yq jq` (Linux).

**CRLF warnings**
Fixed by `.gitattributes` auto-generation. Existing repos: run `enforce` to add it.

## Project Structure

```
git-sentinel/
├── bin/
│   └── git-sentinel          # CLI entrypoint
├── lib/
│   ├── config.sh             # sentinel.yml parser
│   ├── github.sh             # GitHub CLI + API helpers
│   ├── repo.sh               # Repo creation and update
│   ├── branches.sh           # Branch management
│   ├── rulesets.sh            # GitHub Rulesets API
│   ├── files.sh              # File generation
│   ├── templates.sh           # Template injection
│   ├── schema.sh             # Schema output
│   └── log.sh                # Logging + exit codes
├── templates/
│   ├── GIT_REFERENCE.md
│   └── PR_TEMPLATE.md
├── docs/
│   ├── best-practices-public.md
│   └── best-practices-private.md
└── sentinel.example.yml       # Full annotated config
```

## Release Flow

This repo uses two branch-based GitHub Actions workflows:

- `Release PR` (`release-pr.yml`) prepares release PRs before merge.
- `Release Publish` (`release-publish.yml`) publishes the GitHub Release after merge.

The same repository is both the source repo and the Homebrew tap; no GitHub
Pages build or separate published artifact is needed.

```
1. Feature work → PR to develop (squash merge)
2. Ready to release → create branch: release-git-sentinel-v{version} from develop
3. On release branch: bump VERSION in bin/git-sentinel and commit
4. PR release branch → main
5. The Release PR workflow validates the version, tags the release source commit, computes the tag archive SHA256, and commits the formula update back to the release PR
6. Review and merge the main PR
7. The Release Publish workflow creates the GitHub Release from the prepared tag
8. The Release Publish workflow fast-forwards develop to the release PR head
```

### Creating a release

```bash
# From develop
git checkout develop
git pull origin develop
git checkout -b release-git-sentinel-v2.0.1

# Bump version in bin/git-sentinel
git add -A
git commit -m "chore: bump version to v2.0.1"
git push -u origin release-git-sentinel-v2.0.1

# Create the release PR to main
gh pr create --base main --title "release: git-sentinel v2.0.1"

# Wait for the Release PR workflow to add the formula commit and pass again.

# Review and merge the main PR.
# Release Publish will create the GitHub Release and fast-forward develop.
```

The release branch must be named `release-git-sentinel-vX.Y.Z`, and
`git-sentinel version` must print the same version. For example,
`release-git-sentinel-v2.0.1` requires `git-sentinel v2.0.1`.

The formula commit is generated on the release PR before merge. That keeps the
release atomic from Homebrew's point of view: once the PR lands on `main`,
`brew install git-sentinel` points at the new stable tag.

The prepared tag points at the release source commit before the generated
formula commit. That keeps the source archive focused on the tool code while
the formula update lands in the tap on `main`.

Release Publish updates `develop` with a fast-forward-only merge from the
release PR head. If `develop` moved after the release branch was created, the
fast-forward fails; rebase the release branch onto the latest `develop` and
rerun the release.

The fast-forward step uses a short-lived GitHub App installation token generated
from `RELEASE_BACKMERGE_APP_ID` and `RELEASE_BACKMERGE_PRIVATE_KEY`. Install the
app only on this repository and make that app the only bypass actor for the
`develop` ruleset's pull request requirement. GitHub rulesets bypass actors,
not individual workflow files, so these secrets should only be used by Release
Publish.

## License

[GPL-3.0](../LICENSE)
