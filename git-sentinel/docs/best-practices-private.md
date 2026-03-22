# Best Practices — Private Repositories

> Counterpart to [best-practices-public.md](best-practices-public.md).
> Everything not listed here is **identical** to the public repo practices. This document only calls out what's shared (briefly) and what differs.

---

## What's the Same as Public

All of these apply identically — see [best-practices-public.md](best-practices-public.md) for full details:

- **Branch strategy**: `main` + `develop`, with `feature/*`, `release/*`, `fix/*`
- **Merge rules**: squash merge into `develop`, merge commit into `main` from `release-*`
- **Linear git history**: enforced via ruleset
- **Branch protection**: no direct push, no force push, no deletion of `main`/`develop`
- **PR required before merge**: always
- **Required reviews**: user-configured via `required_reviews` in `sentinel.yml` — not a public/private distinction
- **Delete branch on merge**: enabled by default for feature/fix/release branches
- **PR template**: same `.github/PULL_REQUEST_TEMPLATE.md` (What / Why / How / Testing / Checklist)
- **GIT_REFERENCE.md**: same auto-generated reference document
- **Secrets management**: same vigilance — `.gitignore` sensitive files, use vault or env vars, never commit secrets to history

---

## What Differs from Public

### Signed Commits — Optional

Public repos encourage signed commits for supply chain trust. Private repos don't need this by default. If your team wants it, enable it — but git-sentinel does not enforce or encourage it for private repos.

### CONTRIBUTING.md — Not Needed

Public repos need a `CONTRIBUTING.md` to guide external contributors. Private repos don't have external contributors. Skip it.

### LICENSE — Optional

Private repos may or may not need a license file. Set `license:` in `sentinel.yml` if you want one, omit it if you don't. Public repos should always have one.

### README.md — Keep It Lean

Still generated (or user-provided), but for private repos this is internal documentation. No need for badges, install instructions for strangers, or marketing language. Repo name, purpose, and reference links are enough.

---

## Secrets Management (Worth Repeating)

Private does not mean safe. Secrets in git history are permanent, forkable, and one visibility toggle away from public.

- **Never commit secrets** — API keys, tokens, credentials, certificates
- **`.gitignore`** — `.env`, `*.pem`, `*.key`, credentials files
- **Use vault or env vars** — 1Password CLI, `op run`, GitHub Actions secrets, doppler
- **If a secret was committed**: rotate it immediately, then clean history with `git filter-repo`
- **Pre-commit hooks**: consider `git-secrets` or `trufflehog` as a safety net

---

## sentinel.yml — Typical Private Repo Config

```yaml
org: beetlestance
repo: internal-tool
visibility: private
description: "Internal tooling for X"
required_reviews: 0          # solo or small team — adjust as needed
delete_branch_on_merge: true
# license: omitted — not needed for most private repos
# No CONTRIBUTING.md injected
```

---

## TL;DR

| Concern | Public | Private |
|---|---|---|
| Branch strategy | main + develop | **Same** |
| Merge rules | squash / merge commit | **Same** |
| Linear history | Enforced | **Same** |
| Branch protection | Full | **Same** |
| Required reviews | User-configured | **Same** |
| Delete branch on merge | Yes | **Same** |
| PR template | Yes | **Same** |
| GIT_REFERENCE.md | Yes | **Same** |
| Secrets management | Strict | **Same** |
| Signed commits | Encouraged | Optional |
| CONTRIBUTING.md | Yes | No |
| LICENSE | Required | Optional |
