# homebrew-tools: Design Document

## Overview

A personal Homebrew tap for distributing `hc` and `mgmt` — two developer tools currently installable only via `go install` and `uv tool install` respectively. The tap (`will-wright-eng/homebrew-tools`) gives users a single, consistent installation path via `brew install` and keeps versions pinned and auditable.

---

## Repository Structure

```
homebrew-tools/
├── Formula/
│   ├── hc.rb
│   └── mgmt.rb
├── .github/
│   └── workflows/
│       └── audit.yml
└── README.md
```

Homebrew discovers formulas by looking for `.rb` files under `Formula/`. No other structure is required.

---

## Formulas

### `hc` (Go binary)

**Source:** `github.com/will-wright-eng/hc`  
**Language:** Go  
**Current install method:** `go install github.com/will-wright-eng/hc/cmd/hc@latest`

Go binaries are the simplest case for Homebrew. The formula downloads the source tarball for a tagged release and builds it with `go build`. Homebrew handles the `GOPATH` environment and installs the resulting binary into `bin/`.

```ruby
class Hc < Formula
  desc "Hot/Cold codebase analysis — finds hotspots by combining git churn with file complexity"
  homepage "https://github.com/will-wright-eng/hc"
  url "https://github.com/will-wright-eng/hc/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<sha256 of tarball>"
  license "MIT"

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w"), "./cmd/hc"
  end

  test do
    assert_match "hc", shell_output("#{bin}/hc --help")
  end
end
```

**Prerequisites before writing the formula:**
- Tag a release on the `hc` repo (e.g. `v0.1.0`). The formula URL must point to a pinned tag, not `main`, so the sha256 stays stable.
- Compute the sha256: `curl -sL <tarball_url> | shasum -a 256`

---

### `mgmt` (Python CLI)

**Source:** `github.com/will-wright-eng/media-mgmt-cli` / PyPI package `mgmt`  
**Language:** Python  
**Current install method:** `uv tool install mgmt`

Python CLIs use Homebrew's `virtualenv` helper, which creates an isolated venv under the formula's prefix and installs the package plus all dependencies into it. This avoids any conflict with the system Python or other Homebrew Python tools.

```ruby
class Mgmt < Formula
  include Language::Python::Virtualenv

  desc "CLI to search and manage media assets in S3 and locally"
  homepage "https://github.com/will-wright-eng/media-mgmt-cli"
  url "https://files.pythonhosted.org/packages/.../mgmt-0.11.0.tar.gz"
  sha256 "<sha256 from PyPI>"
  license "GPL-3.0-only"

  depends_on "python@3.13"

  # Dependencies are declared as `resource` blocks.
  # Run `brew update-python-resources Formula/mgmt.rb` to generate these automatically.
  resource "boto3" do
    url "https://files.pythonhosted.org/..."
    sha256 "..."
  end

  # ... additional resources ...

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "mgmt", shell_output("#{bin}/mgmt --help")
  end
end
```

**Getting the resource blocks:**  
After writing an initial formula with just the top-level `url` and `sha256`, run:

```bash
brew update-python-resources Formula/mgmt.rb
```

This resolves the full dependency tree from PyPI and fills in the `resource` blocks automatically.

---

## Versioning Strategy

| Tool | Source of truth | How to update |
|------|----------------|---------------|
| `hc` | GitHub release tag | Push a new tag; update `url` + `sha256` in formula |
| `mgmt` | PyPI release | Update `url` + `sha256`; re-run `brew update-python-resources` |

Neither formula tracks `main`/`HEAD`. Every update requires a deliberate version bump, which keeps installs reproducible.

---

## CI: Formula Audit

A GitHub Actions workflow runs `brew audit` on every push and PR to catch formula errors early.

```yaml
# .github/workflows/audit.yml
name: Audit

on:
  push:
    paths:
      - "Formula/**"
  pull_request:
    paths:
      - "Formula/**"

jobs:
  audit:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Homebrew
        uses: Homebrew/actions/setup-homebrew@master

      - name: Tap this repo
        run: brew tap will-wright-eng/tools $(pwd)

      - name: Audit formulas
        run: brew audit --strict will-wright-eng/tools/hc will-wright-eng/tools/mgmt

      - name: Install and test hc
        run: brew install --build-from-source will-wright-eng/tools/hc && brew test will-wright-eng/tools/hc

      - name: Install and test mgmt
        run: brew install --build-from-source will-wright-eng/tools/mgmt && brew test will-wright-eng/tools/mgmt
```

---

## Setup Checklist

**One-time repo setup**
- [ ] Create `will-wright-eng/homebrew-tools` on GitHub (public)
- [ ] Add `Formula/` directory with `.rb` files
- [ ] Add `.github/workflows/audit.yml`
- [ ] Add `README.md` with install instructions

**For `hc`**
- [ ] Tag a release on `will-wright-eng/hc` (e.g. `v0.1.0`)
- [ ] Compute sha256 of the release tarball
- [ ] Write `Formula/hc.rb`

**For `mgmt`**
- [ ] Locate the `mgmt 0.11.0` sdist URL on PyPI
- [ ] Write initial `Formula/mgmt.rb` with top-level url/sha256
- [ ] Run `brew update-python-resources Formula/mgmt.rb` to populate dependencies
- [ ] Verify `brew install --build-from-source will-wright-eng/tools/mgmt`

---

## User-facing Install

Once published, installation is:

```bash
brew tap will-wright-eng/tools
brew install hc
brew install mgmt
```

Or without tapping first:

```bash
brew install will-wright-eng/tools/hc
brew install will-wright-eng/tools/mgmt
```

---

## Maintenance

When a new version of either tool is released:

1. Update the `url` in the relevant formula to point to the new tarball.
2. Update the `sha256` (`curl -sL <url> | shasum -a 256`).
3. For `mgmt`, re-run `brew update-python-resources` if any dependencies changed.
4. Open a PR — CI will audit and test before merge.
5. Merge to `main`. Users get the update on their next `brew upgrade`.
