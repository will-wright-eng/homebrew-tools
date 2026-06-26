# homebrew-tools

A personal [Homebrew](https://brew.sh) tap for `hc` and `mgmt`.

## Install

```bash
brew tap will-wright-eng/tools
brew install hc
brew install mgmt
```

Or in one shot, without tapping first:

```bash
brew install will-wright-eng/tools/hc
brew install will-wright-eng/tools/mgmt
```

## Tools

| Formula | What it is | Upstream |
|---------|-----------|----------|
| `hc` | Find codebase hotspots by combining git churn with file complexity | [will-wright-eng/hc](https://github.com/will-wright-eng/hc) |
| `mgmt` | CLI to search and manage media assets in S3 and locally | [will-wright-eng/media-mgmt-cli](https://github.com/will-wright-eng/media-mgmt-cli) |

`hc` installs a prebuilt release binary; `mgmt` installs into an isolated Python
virtualenv. Both are pinned to specific versions — updates are deliberate version
bumps, not floating `HEAD`. See [`design-doc.md`](./design-doc.md) for details.

## Why a personal tap

A recent dispute around Homebrew surfaced that some Homebrew maintainers run
their own custom taps — useful when the official-tap route is awkward.

Discussion: https://github.com/orgs/Homebrew/discussions/6482

One concrete failure mode it avoids: casks distributing unsigned apps get
disabled by Homebrew's Gatekeeper check —

```text
Deprecated because it does not pass the macOS Gatekeeper check! It will be disabled on 2026-09-01.
```

Distributing `hc` as a *formula* (a CLI binary, not a cask app) sidesteps this:
formula downloads aren't quarantined, so the binary runs without a Gatekeeper
prompt.
