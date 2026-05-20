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

The ruleset JSON files demonstrate policy options such as required status
checks, bypass actors, bypass teams, review counts, code-owner review, allowed
merge methods, linear history, deletion protection, and force-push protection.

Some advanced fields shown in the samples are roadmap examples and may not be
fully supported by the current `sentinel.yml` parser yet.
