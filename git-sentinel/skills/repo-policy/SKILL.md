---
name: git-sentinel-repo-policy
description: Use when a user wants guided help creating a git-sentinel repository policy, including sentinel.yml and GitHub Rulesets JSON payloads for a new or existing GitHub repository.
---

# git-sentinel Repo Policy

Guide the user from intent to a ready-to-review git-sentinel config. Produce
`sentinel.yml` plus ruleset JSON files. Do not validate GitHub ruleset semantics;
GitHub owns that. Keep git-sentinel's boundary to transport basics: file exists,
valid JSON, and each ruleset JSON has `name`.

## Interview

Ask only for missing information. Prefer compact questions and reasonable
defaults.

Required:

- owner or organization
- repository name
- visibility: `private` or `public`
- short description

Recommended:

- branch model: default `main` + `develop`, default branch `develop`
- license: recommended for public repos, optional for private repos
- collaborators
- templates to inject
- release branch policy: approval count, code-owner review, allowed merge methods
- integration branch policy: usually squash only, zero or one review
- required status checks
- bypass actors, if any

## Output Shape

Generate this file layout:

```text
sentinel.yml
rulesets/
  protect-main.json
  protect-develop.json
```

If branch names differ, name rulesets after the branch:

```text
rulesets/
  protect-stable.json
  protect-trunk.json
```

## sentinel.yml

Use ruleset JSON files for policy details. Do not put bypass actors, status
checks, or review policy directly in `sentinel.yml`.

```yaml
org: OWNER
repo: REPO
visibility: private
description: "Short description"

branches:
  - main
  - develop
default_branch: develop

delete_branch_on_merge: true

rulesets:
  - ./rulesets/protect-main.json
  - ./rulesets/protect-develop.json

collaborators: []
templates: []
```

Omit empty optional arrays if the user prefers minimal YAML.

## Ruleset JSON

Each ruleset JSON must include `name`. Keep payloads compatible with GitHub's
Rulesets API, but do not block future GitHub fields.

Release branch example:

```json
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
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge", "rebase"]
      }
    }
  ],
  "bypass_actors": []
}
```

Integration branch example:

```json
{
  "name": "protect-develop",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/develop"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      }
    }
  ],
  "bypass_actors": []
}
```

Add required status checks when the user provides check names:

```json
{
  "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": true,
    "required_status_checks": [
      { "context": "ci/test", "integration_id": null }
    ]
  }
}
```

## Final Response

After creating or showing files, give the next command:

```bash
git-sentinel init --dry-run --config sentinel.yml
```

For existing repositories:

```bash
git-sentinel diff --config sentinel.yml
git-sentinel enforce --dry-run --config sentinel.yml
```
