# git-sentinel Samples

Reference configurations for common repository policy profiles.

These samples are meant to teach the policy model before users run
`git-sentinel init` or `git-sentinel enforce`.

## Profiles

| Profile | Use case |
|---|---|
| `public/` | Open-source or public-facing repositories |
| `private/` | Internal repositories with lighter review requirements |

Each profile includes:

- `sentinel.yml` — desired repo configuration
- `rulesets/protect-main.json` — example GitHub Rulesets API payload
- `rulesets/protect-develop.json` — example GitHub Rulesets API payload

The sample configs use the default `main` and `develop` branch model, but
`branches:` and `default_branch:` can be changed for repositories that use names
such as `stable`, `trunk`, or `next`.

The ruleset JSON files demonstrate policy options such as required status
checks, bypass actors, bypass teams, review counts, code-owner review, allowed
merge methods, linear history, deletion protection, and force-push protection.

git-sentinel only validates transport basics: each ruleset file must exist,
parse as JSON, and include a `name`. It then sends the payloads to the GitHub
Rulesets API. GitHub remains the source of truth for which ruleset options are
accepted.

Paths in each sample `sentinel.yml` are relative to that config file.
