# homebrew-tools

A personal Homebrew tap distributing six developer tools that each ship with a
different, language-specific install path. See [design-doc.md](design-doc.md) for
the formula design and the reasoning behind it.

## Install

```bash
brew tap will-wright-eng/tools
brew install hc mgmt sosig
```

Or without tapping first:

```bash
brew install will-wright-eng/tools/hc
```

## Tools

| Formula | Description | Status |
|---------|-------------|--------|
| `hc` | Hot/cold codebase analysis: git churn crossed with file complexity | Ready |
| `mgmt` | Command-line interface to search and manage media assets in S3 | Ready |
| `sosig` | Analyze GitHub repositories and calculate social-signal metrics | Ready |
| `g3` | Object storage CLI over GitHub Gists, speaking aws-cli vocabulary | Awaiting upstream tag |
| `loch` | Per-commit LOC history via gix and tokei, without a working tree | Awaiting upstream tag |
| `mdcsv` | Convert between markdown tables and CSV | Awaiting upstream tag |

The three pending formulas are committed with placeholder checksums. Each needs its
upstream repo tagged, then the `url` pointed at the tag and the `sha256` filled in.

## Development

```bash
brew tap will-wright-eng/tools "$(pwd)"
brew audit --strict will-wright-eng/tools/<name>
brew install --build-from-source will-wright-eng/tools/<name>
brew test will-wright-eng/tools/<name>
brew uninstall <name>
```

Every formula builds from source, so nothing here downloads an unsigned binary and
the macOS Gatekeeper deprecation that motivated this tap does not apply. That
discussion: https://github.com/orgs/Homebrew/discussions/6482
