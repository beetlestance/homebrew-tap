# Recovery Guide — Interrupted `init`

Use this guide when `git-sentinel init` creates or partially configures a repo
but exits before finishing.

`init` is designed so most failed runs can be resumed with:

```bash
git-sentinel enforce --config sentinel.yml
```

If `sentinel.yml` was removed after a successful init, the repo is already past
the recovery point. Use a fresh config only when you intentionally want to
re-apply policy.

## First Checks

Run:

```bash
git-sentinel doctor --config sentinel.yml
git status --short --branch
git remote -v
```

Confirm:

- `sentinel.yml` still exists
- the current directory name matches `repo:` in `sentinel.yml`
- the `origin` remote points at the intended GitHub repo
- GitHub authentication is valid

## Repo Was Created, Then Init Failed

If GitHub repo creation succeeded but a later step failed, do not run `init`
again. Run:

```bash
git-sentinel enforce --config sentinel.yml
```

`enforce` is the recovery path for applying branches, generated files, rulesets,
and collaborators to an existing repo.

## Local Git Repo Was Initialized

If `.git/` exists locally, `init` will refuse to run again.

Use:

```bash
git-sentinel enforce --config sentinel.yml
```

Only remove `.git/` if you intentionally want to discard the local repository
and start over.

## Branch Push Failed

Check that `origin` is correct:

```bash
git remote -v
```

Then retry with:

```bash
git-sentinel enforce --config sentinel.yml
```

If `main` or `develop` exists remotely already, `enforce` will work with the
existing branches.

## Ruleset Application Failed

Ruleset failures usually mean missing permissions, unsupported repo plan/API
access, or an auth issue.

Run:

```bash
git-sentinel doctor --config sentinel.yml
```

After fixing access, retry:

```bash
git-sentinel enforce --config sentinel.yml
```

## Generated Files Failed

Common causes:

- configured `readme:` path does not exist
- a `templates:` path does not exist
- local filesystem permissions block writes

Fix the path or permission issue, then run:

```bash
git-sentinel enforce --config sentinel.yml
```

## Collaborator Addition Failed

Collaborator failures are usually non-fatal and can be retried.

Check that the usernames are correct:

```yaml
collaborators:
  - username
```

Then run:

```bash
git-sentinel enforce --config sentinel.yml
```

## When To Delete And Start Over

Delete and recreate only when the wrong GitHub repo was created or the wrong
local directory was initialized.

Before deleting anything, verify:

```bash
gh repo view ORG/REPO
git remote -v
```

If the repo is wrong and safe to remove:

```bash
gh repo delete ORG/REPO
```

Then recreate the local directory with the correct name and run `init` again.
