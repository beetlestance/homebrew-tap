# homebrew-tap

Beetlestance CLI tools, distributed via Homebrew.

```bash
brew tap beetlestance/tap
```

## Tools

| Tool | Description | Install |
|---|---|---|
| [git-sentinel](git-sentinel/) | GitHub repo setup and ruleset enforcement | `brew install beetlestance/tap/git-sentinel` |

More tools coming — each gets its own directory in this repo.

## How It Works

This is a [Homebrew tap](https://docs.brew.sh/Taps) — a third-party repository of Homebrew formulae. Tapping adds our tools to your local Homebrew, and `brew install` handles the rest.

## Contributing

1. Create a feature branch from `develop`
2. Submit a PR to `develop` (squash merge enforced)
3. Release branches merge to `main` (merge commit)

See [GIT_REFERENCE.md](GIT_REFERENCE.md) for branch strategy and merge rules.

## License

[GPL-3.0](LICENSE)
