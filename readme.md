# homebrew-tools

A personal Homebrew tap distributing six developer tools that each ship with a
different, language-specific install path. See [design-doc.md](docs/design-doc.md) for
the formula design and the reasoning behind it, and
[formula-readiness.md](docs/formula-readiness.md) for current status and open work.

## Install

```bash
brew tap will-wright-eng/tools
brew install g3 hc loch mdcsv mgmt sosig
```

Or without tapping first:

```bash
brew install will-wright-eng/tools/hc
```

## Tools

| Formula | Description | Version | Status |
|---------|-------------|---------|--------|
| `g3` | Object storage CLI over GitHub Gists, speaking aws-cli vocabulary | `0.1.0` | Ready |
| `hc` | Hot/cold codebase analysis: git churn crossed with file complexity | `1.4.1` | Ready; `1.4.2` bump pending |
| `loch` | Per-commit LOC history via gix and tokei, without a working tree | `0.1.0` | Ready |
| `mdcsv` | Convert between markdown tables and CSV | `0.1.0` | Ready |
| `mgmt` | Command-line interface to search and manage media assets in S3 | `0.11.0` | Ready |
| `sosig` | Analyze GitHub repositories and calculate social-signal metrics | `0.3.0` | Ready; `0.3.1` sdist switch pending |

## CI

- `audit.yml` runs `brew audit --strict`, `brew install --build-from-source`, and
  `brew test` for every formula on pushes and PRs that touch `Formula/`.
- `livecheck.yml` runs `brew livecheck` monthly and opens a `livecheck/bump` PR for
  any formula behind upstream.
- Dependabot keeps the SHA-pinned actions current.

## Development

```bash
brew tap will-wright-eng/tools "$(pwd)"
brew audit --strict will-wright-eng/tools/<name>
brew install --build-from-source will-wright-eng/tools/<name>
brew test will-wright-eng/tools/<name>
brew livecheck will-wright-eng/tools/<name>
brew uninstall <name>
```

Every formula builds from source, so nothing here downloads an unsigned binary and
the macOS Gatekeeper deprecation that motivated this tap does not apply.

## References

- [design-doc.md](docs/design-doc.md): formula design by language
- [formula-readiness.md](docs/formula-readiness.md): status, tasks, and upstream checks
- [Homebrew discussion #6482](https://github.com/orgs/Homebrew/discussions/6482): the Gatekeeper/custom-tap thread
- [Homebrew Taps documentation](https://docs.brew.sh/Taps)
