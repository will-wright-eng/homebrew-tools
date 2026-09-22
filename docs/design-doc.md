# homebrew-tools: Design Document

## Overview

A personal Homebrew tap (`will-wright-eng/homebrew-tools`) distributing six developer
tools that today each have a different, language-specific install path — `go install`,
`cargo build`, `uv tool install`, or `git clone && make install`. The tap collapses
those into one command per tool, with pinned versions and auditable checksums.

Scope is deliberately a **tap**, not submissions to `homebrew-core`. Core requires
notability thresholds (maintained, stable, widely used) these tools do not meet, and
core rejects HEAD-only and unversioned formulas outright. A tap has no such gate.

The `readme.md` note about the Gatekeeper deprecation
(`does not pass the macOS Gatekeeper check`) applies to **casks** shipping signed
`.app`/binary artifacts, not to formulas. Every formula here builds from source on the
user's machine or installs a Python wheel into a virtualenv, so Gatekeeper never sees a
downloaded executable. `Homebrew/deprecate_disable.rb` exposes `:fails_gatekeeper_check`
only as a cask deprecation reason, and the audit that enforces it lives in
`Library/Homebrew/cask/audit.rb`. This tap is unaffected.

All six formulas are committed. Three — `hc`, `mgmt`, and `sosig` — are installable
today. The other three are written and verified but carry placeholder checksums until
their repos are tagged; see
[Prerequisites](#prerequisites-blocking-work-outside-this-repo).

---

## Tool Inventory

Facts below were read from each repository and from PyPI, not assumed.

| Tool | Repo | Language | Binary | License | Release state |
|------|------|----------|--------|---------|---------------|
| `hc` | `will-wright-eng/hc` | Go 1.26.1 | `hc` | GPL-3.0-or-later | Tagged: `v1.4.1`, goreleaser assets |
| `loch` | `will-wright-eng/loch` | Rust 1.85 | `loch` | **none** | **No tags, no releases** |
| `g3` | `will-wright-eng/gists3` | Go 1.22 | `g3` | MIT | **No tags, no releases** |
| `sosig` | `will-wright-eng/social-signals` | Python ≥3.10 | `sosig` | **none** | Tagged `v0.3.0`; on PyPI as `sosig` |
| `mgmt` | `will-wright-eng/media-mgmt-cli` | Python ≥3.9 | `mgmt` | GPL-3.0-or-later | Tagged `v0.11.0`; on PyPI as `mgmt` |
| `mdcsv` | `will-wright-eng/mdcsv` | Go 1.23.4 | `mdcsv` | **none** | **No tags, no releases** |

Three tools are blocked on tags in their own repos, and `sosig` ships with two
non-blocking upstream fixes outstanding; see
[Prerequisites](#prerequisites-blocking-work-outside-this-repo).

### Name collisions

Every proposed formula name was checked against the Homebrew API. `hc`, `loch`, `g3`,
`gists3`, `sosig`, `mgmt`, and `mdcsv` all return `404` for both
`formulae.brew.sh/api/formula/<name>.json` and the cask equivalent — no collisions in
core. Within a tap, a colliding name is still installable via the fully-qualified
`will-wright-eng/tools/<name>`, so this is a convenience concern rather than a blocker.

Note the `gists3` repo ships **two** commands under `cmd/`: `g3` (the real CLI) and
`example`. The formula is named `g3` after the binary, not after the repo, and builds
only `./cmd/g3`. No `gists3` alias is provided: the command users type is `g3`, and a
second name is one more thing to keep in sync for no discoverability gain.

---

## Repository Structure

```
homebrew-tools/
├── Formula/
│   ├── g3.rb
│   ├── hc.rb
│   ├── loch.rb
│   ├── mdcsv.rb
│   ├── mgmt.rb
│   └── sosig.rb
├── .github/
│   └── workflows/
│       └── audit.yml
├── design-doc.md
└── readme.md
```

`g3.rb`, `loch.rb`, and `mdcsv.rb` are committed with a placeholder `sha256`. Their build
logic was verified against pinned commits of each repo's `main` (see
[Interim option](#interim-option-pinned-commit-urls)), so tagging reduces to swapping the
`url` and filling in the real checksum.

Homebrew discovers formulas from `.rb` files under `Formula/`. The class name is the
CamelCased filename (`g3.rb` → `class G3`), and the default install target is
`bin/<formula name>` — which is why the formula name must match the intended command.

---

## Formula Design by Language

### Go formulas: `hc`, `g3`, `mdcsv`

Go is the simplest case. Homebrew provides `std_go_args`, which sets `-o bin/<name>`,
`-trimpath`, and the module flags. Homebrew's `go` is 1.27.1, which satisfies every
`go` directive in the three repos (1.26.1, 1.22, 1.23.4).

`std_go_args(ldflags:)` already prepends `-s -w` unless debug symbols are requested
(`formula.rb:2308` tests `ENV.debug_symbols?`, which `brew install --debug-symbols`
sets), so passing `ldflags: "-s -w"` duplicates them. Pass only the flags the project
actually needs.

#### `hc`

`hc` declares `version` and `commit` as `main`-package variables (`cmd/hc/main.go:25-28`)
and renders them through `Version: fmt.Sprintf("%s (%s)", version, commit)`
(`cmd/hc/main.go:102`). Built without ldflags it reports `dev (none)`. Homebrew's
`std_go_args(ldflags: :goreleaser)` injects `main.version`, `main.commit`, `main.date`,
and `main.builtBy`; `hc`'s own `.goreleaser.yaml` sets only the first two, so `date` and
`builtBy` are written to variables the program does not declare — harmless, and the two
that matter line up. Use it so `hc --version` is truthful.

```ruby
class Hc < Formula
  desc "Hot/cold codebase analysis: git churn crossed with file complexity"
  homepage "https://github.com/will-wright-eng/hc"
  url "https://github.com/will-wright-eng/hc/archive/refs/tags/v1.4.1.tar.gz"
  sha256 "590cae7805d61d319456db04e3ffc35742b0167b8e70b9623efbd12689370236"
  license "GPL-3.0-or-later"
  head "https://github.com/will-wright-eng/hc.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: :goreleaser), "./cmd/hc"
  end

  test do
    assert_match "Hot/Cold codebase analysis", shell_output("#{bin}/hc --help")
    assert_match version.to_s, shell_output("#{bin}/hc --version")
  end
end
```

The `sha256` above is the **real** checksum of the `v1.4.1` source tarball, verified with
`curl -sL <url> | shasum -a 256`. Note this is the GitHub-generated source archive, not
one of the goreleaser release assets — those have their own, different checksums
(published in `checksums.txt`) and are only relevant if the tap ever switches to
shipping prebuilt binaries.

#### `mdcsv`

All code is in a single top-level `main.go`, so the build target is `.`, not `./cmd/...`.
`mdcsv --help` exits `0` and prints to stdout — verified.

```ruby
class Mdcsv < Formula
  desc "Convert between markdown tables and CSV"
  homepage "https://github.com/will-wright-eng/mdcsv"
  url "https://github.com/will-wright-eng/mdcsv/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<sha256 of the v0.1.0 tarball, once tagged>"
  license "GPL-3.0-or-later" # no LICENSE file upstream yet; see Prerequisites
  head "https://github.com/will-wright-eng/mdcsv.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args, "."
  end

  test do
    assert_match "usage: mdcsv", shell_output("#{bin}/mdcsv --help")
  end
end
```

#### `g3`

Two gotchas, both verified by running the built binary:

1. `g3` has no `--help` flag. `g3 --help` prints `g3: unknown command "--help"`,
   writes the usage text **to stderr**, and exits **2**. The same is true of `g3` with
   no arguments and of `g3 help`.
2. `shell_output(cmd)` asserts an exit status of `0` by default
   (`formula_assertions.rb:32`) and merges stderr into the captured output
   (`err: :err`). So the test must pass the expected status explicitly.

```ruby
class G3 < Formula
  desc "Object storage CLI over GitHub Gists, speaking aws-cli vocabulary"
  homepage "https://github.com/will-wright-eng/gists3"
  url "https://github.com/will-wright-eng/gists3/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<sha256 of the v0.1.0 tarball, once tagged>"
  license "MIT"
  head "https://github.com/will-wright-eng/gists3.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args, "./cmd/g3"
  end

  test do
    # g3 has no --help flag: usage goes to stderr with exit status 2.
    assert_match "usage: g3", shell_output("#{bin}/g3 2>&1", 2)
  end
end
```

`g3` has zero dependencies beyond the Go standard library, so there is no `go.sum` to
vendor and the build is fully offline after the tarball is fetched.

---

### Rust formula: `loch`

Homebrew provides `std_cargo_args`, which expands to
`--jobs N --locked --root=#{prefix} --path=.` (`formula.rb:2219`). It also appends
`--offline`, but only for formulas that define their own `fetch` method; `loch` does
not, so the flag does not apply here. The `--locked` flag requires a committed
`Cargo.lock` — `loch` has one.

Two facts from `Cargo.toml` shape this formula:

- `rust-version = "1.85"`; Homebrew's `rust` is 1.98.1, so the toolchain is satisfied.
- A comment in the manifest records that the crates.io name `loch` is squatted by a
  dormant 2019 crate. That only matters for `cargo install loch` from the registry;
  building from the GitHub tarball with `--path=.` bypasses crates.io entirely, and the
  produced binary is named `loch` because the package is. **No rename is needed for the
  tap.** If the crate is ever published as `loch-cli`, the formula keeps working
  unchanged as long as it keeps building from the git source.

```ruby
class Loch < Formula
  desc "Per-commit LOC history via gix and tokei, without a working tree"
  homepage "https://github.com/will-wright-eng/loch"
  url "https://github.com/will-wright-eng/loch/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<sha256 of the v0.1.0 tarball, once tagged>"
  license "GPL-3.0-or-later" # no LICENSE file upstream yet; see Prerequisites
  head "https://github.com/will-wright-eng/loch.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/loch --version")
    system bin/"loch", "--help"
  end
end
```

`loch` derives `clap::Parser` with `version` (`src/main.rs:10-15`), so `--version` prints
the `Cargo.toml` version and `--help` exits `0`.

`gix` and `tokei` are pinned to exact versions (`=0.85.0`, `=14.0.0`) and pull a large
dependency tree, but the build parallelises well: 30 seconds on an arm64 Mac. The
slowest formula in the tap is `sosig`, which compiles `pydantic-core` from Rust source.

---

### Python formulas: `mgmt` and `sosig`

Both use Homebrew's `Language::Python::Virtualenv`, which builds an isolated venv under
`libexec` and symlinks entry-point scripts into `bin`. Nothing touches the system Python.

Two non-obvious mechanics drive the design, both confirmed by reading
`Library/Homebrew/language/python.rb`:

- `virtualenv_install_with_resources` installs every `resource` block, then installs the
  **staged source root** (`buildpath`). It therefore assumes the main `url` is an sdist
  that unpacks to a buildable directory.
- Homebrew's `pip_install` runs pip with `--no-binary=:all:`, forcing *every* dependency
  to build from source. The flag itself comes from `std_pip_args`
  (`formula.rb:2347`), which `pip_install` reaches via its private `do_install`. Any
  dependency with a compiled extension needs its build toolchain declared as a
  formula-level `depends_on ... => :build`.

Both formulas pin `python@3.14`, Homebrew's current default. Bumping to a later Python
means editing two places in `sosig.rb` — the `depends_on` line and the
`virtualenv_create` call — and one in `mgmt.rb`.

#### `mgmt`

The PyPI sdist for `mgmt 0.11.0` is well-formed — verified by extracting it and building
it in a clean venv, which produced a working `mgmt` binary whose `--help` exits `0`.
So the standard pattern applies.

One discrepancy worth recording: the repo's `pyproject.toml` lists
`botocore[crt]>=1.29.54` as a dependency, but the **published** `0.11.0` metadata does
not (`Requires-Dist` is only `boto3`, `rich`, `typer`). `brew update-python-resources`
reads published metadata, so the `crt` extra — which pulls the compiled `awscrt`
package — will not be resolved. That is the desired outcome here: it keeps the build
free of a C/C++ extension. If a future release republishes with `botocore[crt]`, the
formula will need a `cmake` build dependency.

```ruby
class Mgmt < Formula
  include Language::Python::Virtualenv

  desc "Command-line interface to search and manage media assets in S3"
  homepage "https://github.com/will-wright-eng/media-mgmt-cli"
  url "https://files.pythonhosted.org/packages/c5/ad/c984b6650881af01d8fc8791f847908dcfcae300d1aff3980212e52e998a/mgmt-0.11.0.tar.gz"
  sha256 "e43b3837af90b3dc532f87b801d10f3d7c0aad03198e598d5e92ad9b1d51d48c"
  license "GPL-3.0-or-later"

  livecheck do
    url :stable
    strategy :pypi
  end

  depends_on "python@3.14"

  # Generated by `brew update-python-resources Formula/mgmt.rb`.
  # Transitive deps of boto3, rich, and typer.
  resource "boto3" do
    url "https://files.pythonhosted.org/..."
    sha256 "..."
  end

  # ... remaining resources ...

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "Usage: mgmt", shell_output("#{bin}/mgmt --help")
  end
end
```

The `url` and `sha256` are the real published sdist values, read from the PyPI JSON API.

#### `sosig` — the sdist is broken, so install the wheel

`sosig`'s published sdist **cannot be built**, and this was confirmed three ways.

The package lives in the `sosig/` subdirectory of the `social-signals` repo, and its
`pyproject.toml` declares `readme = "../README.md"` — a path outside the package root.
Two consequences:

1. The sdist contains a literal `sosig-0.3.0/../README.md` member. GNU/BSD `tar` refuses
   it: `Path contains '..': Unknown error`.
2. Even after extracting the rest, hatchling refuses to generate metadata:
   `ValueError: Readme path must be within the project directory: ../README.md`.
   `pip install ./sosig-0.3.0` fails with `metadata-generation-failed`.

The `sosig-0.3.0-py3-none-any.whl` on PyPI, by contrast, installs cleanly — the readme
was already resolved into `PKG-INFO` at build time. So the formula installs the wheel.

Three adjustments are needed to make a wheel work as a formula's main `url`. Each one
was found by hitting the failure, not by guessing:

1. **`using: :nounzip`.** Homebrew treats a `.whl` as a zip and unpacks it into the
   staging directory, after which pip reports
   `Directory '...' is not installable. Neither 'setup.py' nor 'pyproject.toml' found.`
   `:nounzip` leaves the file intact.
2. **Copy `cached_download` to a correctly-named file.** Homebrew's download cache
   prefixes filenames with a hash (`4d4e18ae...--sosig-0.3.0-py3-none-any.whl`), and pip
   rejects that: `Invalid wheel filename (wrong number of parts)`. Copying it to
   `sosig-#{version}-py3-none-any.whl` in `buildpath` restores a PEP 427 filename.
3. **`depends_on "rust" => :build`.** `sosig` depends on `sqlmodel` → `pydantic` →
   `pydantic-core`, which is written in Rust. Because Homebrew's `pip_install` forces
   `--no-binary=:all:`, the prebuilt `pydantic-core` wheel is ignored and it is compiled
   from source. Without the Rust toolchain the build dies at
   `Failed to build 'pydantic_core-2.46.5' when installing build dependencies`.
   Homebrew's own audit requires `rust` be listed before `python@3.14`.

```ruby
class Sosig < Formula
  include Language::Python::Virtualenv

  desc "Analyze GitHub repositories and calculate social-signal metrics"
  homepage "https://github.com/will-wright-eng/social-signals"
  # The 0.3.0 sdist is unbuildable: pyproject.toml points readme at ../README.md,
  # outside the package root, so hatchling rejects it. Install the wheel instead.
  url "https://files.pythonhosted.org/packages/0c/91/5a0be09985bb88704534f2b733c0b03c99586770a292d8d8e22501ef411d/sosig-0.3.0-py3-none-any.whl", using: :nounzip
  sha256 "7097eb473b1d620a08f0bdd38ac34686bcb1756c63d186b206f57e56eb4eb0f5"

  # `strategy :pypi` derives the package name from the filename and reads
  # "sosig-0.3.0-py3-none" off a wheel URL, so the project page is named directly.
  livecheck do
    url "https://pypi.org/pypi/sosig/json"
    regex(/"version":\s*"([^"]+)"/i)
  end

  # pip runs with --no-binary=:all:, so pydantic-core is built from Rust source.
  depends_on "rust" => :build
  depends_on "python@3.14"

  # Generated by:
  #   brew update-python-resources --package-name sosig Formula/sosig.rb
  resource "annotated-doc" do
    url "https://files.pythonhosted.org/packages/5a/8e/.../annotated_doc-0.0.5.tar.gz"
    sha256 "c7e58ce09192557605d8bbd92836d7e1d520ac9580096042c0bfd197efacf1bb"
  end

  # ... 13 more resources ...

  def install
    # The cached download is hash-prefixed; pip needs a PEP 427 filename.
    wheel = buildpath/"sosig-#{version}-py3-none-any.whl"
    cp cached_download, wheel

    venv = virtualenv_create(libexec, "python3.14")
    venv.pip_install resources
    venv.pip_install_and_link wheel
  end

  test do
    assert_match "Usage", shell_output("#{bin}/sosig --help")
  end
end
```

`virtualenv_install_with_resources` cannot be used here, because it installs `buildpath`
rather than the wheel. The three-line expansion above is that helper's body with the
final target swapped.

**Resource generation needs an explicit package name.** `brew update-python-resources`
parses the main `url` with a regex that only accepts `.tar.gz`/`.zip`
(`utils/pypi.rb:171`) and fails on a wheel URL with
`Error: Package should be a valid PyPI URL`. Passing `--package-name sosig` skips that
inference. This resolved 14 resources successfully. The same wheel-versus-sdist
assumption breaks `livecheck`'s `:pypi` strategy, which is why that block names the
project URL outright.

**This formula was built and installed end to end.** In a scratch tap, `brew audit
--strict` passed, `brew install --build-from-source` completed in 1m23s (22.5MB, 1,092
files), and `brew test` passed.

The upstream fix is to set `readme` to a path inside `sosig/` (or drop it and rely on
`project.readme` defaults) and republish; the formula could then use the normal sdist
pattern and the ordinary `strategy :pypi` livecheck. That is a change to the
`social-signals` repo, not to this one.

`sosig` also leaves a side effect worth knowing: it creates its data directory on
**import**, not on first command, because its `__init__.py` calls `get_db()` at module
scope. The location is XDG-aware — `$XDG_DATA_HOME/sosig` when that variable is set,
otherwise `~/.local/share/sosig/` (`src/sosig/core/config.py:18-27`). `brew test`
triggers this. It is harmless but not idiomatic. `mgmt` has no equivalent behaviour; its
`__init__.py` is a bare re-export.

---

## Prerequisites (blocking work outside this repo)

Three of the six tools cannot get a correct formula until their own repos change. A
formula's `url` must point at an immutable artifact — a tag or a commit SHA — because a
branch tarball's `sha256` changes on every push, breaking every install.

| Tool | Blocker | Fix (in that repo) |
|------|---------|--------------------|
| `loch` | No tags/releases; **no LICENSE** | `git tag v0.1.0 && git push --tags`; add a LICENSE file |
| `g3` | No tags/releases | `git tag v0.1.0 && git push --tags` (LICENSE is MIT, present) |
| `mdcsv` | No tags/releases; **no LICENSE** | `git tag v0.1.0 && git push --tags`; add a LICENSE file |

`sosig` ships now but carries two upstream fixes that are not blocking:
`social-signals` has **no LICENSE file** (the GitHub API reports none, and PyPI carries
no license metadata), and its sdist is unbuildable. Both should be fixed and the package
republished; the second is what would let the formula drop the wheel machinery.

### On the missing licenses

`brew audit --strict` does **not** fail a tap formula for a missing `license` stanza —
only for a non-SPDX or deprecated identifier. But omitting it is wrong for a different
reason: with no LICENSE file, `loch`, `mdcsv`, and `social-signals` are "all rights
reserved" by default, and distributing them via a public tap invites users to install
code they have no license to use. Add a LICENSE before tagging.

`loch` and `mdcsv` take **`GPL-3.0-or-later`**, matching `hc` and `mgmt`. GPL is the
default for tools authored here; `gists3`'s MIT is the exception, not the pattern.

For the GPL tools, the correct SPDX identifier is `GPL-3.0-or-later`, not
`GPL-3.0-only`. The LICENSE files include the standard "either version 3 of the
License, or (at your option) any later version" grant. `GPL-3.0` (no suffix) is
deprecated in the SPDX list and should not be used — `brew audit --strict` rejects it.

### Interim option: pinned-commit URLs

If tagging is deferred, a commit SHA is also immutable and works today:

```ruby
url "https://github.com/will-wright-eng/mdcsv/archive/d4b5fc5a9994f2e6b0e95ff5093fe08fd381d1f5.tar.gz"
version "0.1.0"   # required: Homebrew cannot infer a version from a SHA URL
sha256 "e389ce02d79cccb06e695beafa5851195a5d250797468f8ff8914c37675dbd8d"
```

**This was verified end to end** for all three blocked formulas. With a pinned-commit
`url`/`version`/`sha256` substituted into each, `brew audit --strict` passed, and
`brew install --build-from-source` plus `brew test` succeeded: `mdcsv` in 2s, `g3` in
3s, `loch` in 30s. Only the `url` and `sha256` lines differ from the committed
formulas, so tagging cannot break the build logic.

Tagging is still preferred — a `version` that is unrelated to any upstream marker is a
maintenance trap — and it is the route taken here. The three blocked tools wait for tags
rather than shipping on pinned commits. Treat pinned commits as a bridge available if a
tool needs to ship before its repo is ready, not as a destination.

### `head` blocks

The four source-built formulas (`hc`, `loch`, `g3`, `mdcsv`) each include a `head`
stanza so `brew install --HEAD <tool>` tracks `main`. This is allowed in taps
(`formula_auditor.rb:875` only rejects *HEAD-only* formulas, and only for core). It
gives a supported way to install untagged work without compromising the stable,
checksummed path. The two Python formulas have no `head`: their `url` points at a
published PyPI artifact rather than a git remote.

---

## Description Strings

`brew audit` enforces rules on `desc` via `RuboCop::Cop::DescHelper`: ≤80 characters, no
leading article, starts with a capital, no trailing full stop, must not start with the
formula name, `command-line` must be hyphenated, no emoji. All six were checked against
those rules:

| Formula | `desc` | Length |
|---------|--------|--------|
| `hc` | Hot/cold codebase analysis: git churn crossed with file complexity | 66 |
| `loch` | Per-commit LOC history via gix and tokei, without a working tree | 64 |
| `g3` | Object storage CLI over GitHub Gists, speaking aws-cli vocabulary | 65 |
| `sosig` | Analyze GitHub repositories and calculate social-signal metrics | 63 |
| `mgmt` | Command-line interface to search and manage media assets in S3 | 62 |
| `mdcsv` | Convert between markdown tables and CSV | 39 |

Note `mgmt`'s upstream summary begins "An intuitive command line interface…", which
would trip three separate rules (leading article, unhyphenated "command line", and
length). The rewrite above is deliberate.

---

## Versioning Strategy

| Tool | Source of truth | Update procedure |
|------|----------------|------------------|
| `hc` | GitHub release tag | Bump `url` tag, recompute `sha256` |
| `loch` | GitHub release tag | Bump `url` tag, recompute `sha256` |
| `g3` | GitHub release tag | Bump `url` tag, recompute `sha256` |
| `mdcsv` | GitHub release tag | Bump `url` tag, recompute `sha256` |
| `mgmt` | PyPI sdist | Bump `url`/`sha256`, re-run `brew update-python-resources` |
| `sosig` | PyPI wheel | Bump `url`/`sha256`, re-run with `--package-name sosig` |

No formula tracks a moving branch on its stable path. Every update is a deliberate,
reviewable commit.

Every formula also builds from source on the user's machine; none ship prebuilt
binaries. `hc` publishes goreleaser assets for darwin/linux × amd64/arm64, so a
binary-download formula (`on_macos`/`on_arm` blocks selecting the right asset) would
install in seconds instead of minutes — but that is also the point at which Gatekeeper
becomes relevant again, since an unsigned downloaded binary is exactly what the
deprecation in `readme.md` targets. Source builds sidestep it and keep every formula
uniform. Revisit if `loch`'s Rust build time becomes annoying once it ships.

### `livecheck`

Every formula carries a `livecheck` block so `brew livecheck` reports when the tap is
behind upstream. The four GitHub-sourced formulas use:

```ruby
livecheck do
  url :stable
  strategy :github_latest
end
```

`mgmt` uses `url :stable` with `strategy :pypi`. `sosig` cannot: the strategy derives a
package name from the URL filename, which yields `sosig-0.3.0-py3-none` for a wheel and
requests a project page that does not exist. Its block names
`https://pypi.org/pypi/sosig/json` directly and matches the version out of the JSON.

---

## CI: Formula Audit

The workflow audits, installs, and tests every formula on push and PR. Two details
matter:

- `brew tap <user>/<name> <path>` with a local path taps the working copy directly, so CI
  tests the committed formulas rather than whatever is published.
- Building `sosig` compiles `pydantic-core` from Rust source, which is slow. The job
  needs a generous timeout.

The matrix covers all six formulas. The three awaiting upstream tags carry placeholder
checksums, so their CI jobs fail at the download step until the `url`/`sha256` pair is
filled in — a visible reminder rather than a silent gap.

```yaml
# .github/workflows/audit.yml
name: Audit

on:
  push:
    paths:
      - "Formula/**"
      - ".github/workflows/audit.yml"
  pull_request:
    paths:
      - "Formula/**"
      - ".github/workflows/audit.yml"

permissions:
  contents: read

jobs:
  audit:
    runs-on: macos-latest
    timeout-minutes: 90
    strategy:
      fail-fast: false
      matrix:
        formula: [hc, loch, g3, mdcsv, mgmt, sosig]
    steps:
      - uses: actions/checkout@v4

      - name: Set up Homebrew
        uses: Homebrew/actions/setup-homebrew@master

      - name: Tap this working copy
        run: brew tap will-wright-eng/tools "$(pwd)"

      - name: Audit
        run: brew audit --strict will-wright-eng/tools/${{ matrix.formula }}

      - name: Install
        run: brew install --build-from-source will-wright-eng/tools/${{ matrix.formula }}

      - name: Test
        run: brew test will-wright-eng/tools/${{ matrix.formula }}
```

A matrix is used rather than one job over all formulas so a single broken formula does
not mask the others, and so the slow Rust builds run in parallel with the fast Go ones.
`fail-fast: false` keeps the rest running after one failure.

`brew test-bot` is the alternative to hand-rolling audit/install/test. It is what
`homebrew-core` uses and it handles bottling, but it assumes core's PR conventions; the
explicit three steps above are easier to reason about for a personal tap.

---

## Setup Checklist

**One-time repo setup**
- [x] Add `Formula/` with the six `.rb` files
- [x] Add `.github/workflows/audit.yml`
- [x] Expand `readme.md` with install instructions

**Ready now (no upstream changes needed)**
- [x] `Formula/hc.rb` — tag `v1.4.1`, sha256 verified; installs and tests clean
- [x] `Formula/mgmt.rb` — PyPI sdist pinned; 14 resources generated
- [x] `Formula/sosig.rb` — wheel pattern verified; 14 resources generated via
      `--package-name sosig`

**Blocked on the tool's own repo** — formula written, awaiting an immutable `url`
- [ ] `loch` — add a GPL-3 LICENSE, tag `v0.1.0`, then fill in `Formula/loch.rb`'s `sha256`
- [ ] `g3` — tag `v0.1.0`, then fill in `Formula/g3.rb`'s `sha256`
- [ ] `mdcsv` — add a GPL-3 LICENSE, tag `v0.1.0`, then fill in `Formula/mdcsv.rb`'s `sha256`

**Non-blocking upstream follow-ups**
- [ ] `social-signals` — add a LICENSE file
- [ ] `social-signals` — fix `readme = "../README.md"`, republish, then move
      `Formula/sosig.rb` to the sdist pattern

**Per-formula verification loop**

```bash
brew tap will-wright-eng/tools "$(pwd)"
brew audit --strict will-wright-eng/tools/<name>
brew install --build-from-source will-wright-eng/tools/<name>
brew test will-wright-eng/tools/<name>
brew uninstall <name>
```

If `brew audit` crashes with a vendored-gem `NoMethodError` rather than reporting
findings, the local gem bundle is stale. `brew install-bundler-gems --add-groups=audit`
repairs it.

---

## User-facing Install

```bash
brew tap will-wright-eng/tools
brew install hc mgmt sosig
```

Or without tapping first:

```bash
brew install will-wright-eng/tools/hc
```

Note the tap is named `will-wright-eng/tools`: `brew tap` strips the `homebrew-` prefix
from the repository name `homebrew-tools`.

---

## Maintenance

When a new version of a tool is released:

1. Update `url` to the new tag or sdist/wheel.
2. Recompute the checksum: `curl -sL <url> | shasum -a 256`.
3. For `mgmt`/`sosig`, re-run `brew update-python-resources` (add
   `--package-name sosig` for the wheel-based formula).
4. Open a PR — CI audits, installs, and tests before merge.
5. Merge to `main`. Users pick it up on the next `brew upgrade`.

`brew bump-formula-pr --url=<new-url> --sha256=<new-sha>` automates steps 1–2 and opens
the PR; `brew bump-python-resources-pr` does the same for the resource blocks.

---

## References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Python for Formula Authors](https://docs.brew.sh/Python-for-Formula-Authors)
- [Homebrew Taps documentation](https://docs.brew.sh/Taps)
- [Homebrew Acceptable Formulae](https://docs.brew.sh/Acceptable-Formulae) — why these belong in a tap, not core
- [Homebrew `brew livecheck` documentation](https://docs.brew.sh/Brew-Livecheck)
- [SPDX License List](https://spdx.org/licenses/) — `GPL-3.0-or-later`, `MIT`
- [PEP 427 — The Wheel Binary Package Format](https://peps.python.org/pep-0427/) — wheel filename rules
- [Homebrew discussion #6482](https://github.com/orgs/Homebrew/discussions/6482) — the Gatekeeper/custom-tap thread in `readme.md`
- Homebrew source consulted directly: `Library/Homebrew/formula.rb` (`std_go_args`, `std_cargo_args`, `std_pip_args`), `Library/Homebrew/language/python.rb` (`virtualenv_install_with_resources`, `pip_install`), `Library/Homebrew/formula_assertions.rb` (`shell_output`), `Library/Homebrew/rubocops/shared/desc_helper.rb`, `Library/Homebrew/utils/pypi.rb`, `Library/Homebrew/livecheck/strategy/pypi.rb`
