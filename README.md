# homebrew-tap

Beetlestance CLI tools, distributed via Homebrew.

```bash
brew tap beetlestance/tap
brew install git-sentinel
```

## Tools

| Tool | Description | Install |
|---|---|---|
| [git-sentinel](git-sentinel/) | GitHub repo setup and ruleset enforcement | `brew install beetlestance/tap/git-sentinel` |

More tools coming — each gets its own directory in this repo.

## How It Works

This is a [Homebrew tap](https://docs.brew.sh/Taps) — a third-party repository of Homebrew formulae. Tapping adds our tools to your local Homebrew, and `brew install` handles the rest.

Stable installs come from tagged GitHub releases. The `Release PR` workflow commits the release tarball URL and SHA256 back onto the release PR before it is merged; once that PR lands on `main`, `brew install git-sentinel` installs that version. The `Release Publish` workflow then creates the GitHub Release from the prepared tag. Moving `develop` builds are still available with `brew install --HEAD git-sentinel`.

## Feedback

Issues and feature requests are welcome — [open an issue](https://github.com/beetlestance/homebrew-tap/issues).

## License

[GPL-3.0](LICENSE)
