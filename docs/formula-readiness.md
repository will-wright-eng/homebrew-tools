# Formula Readiness

## Summary

Three of the six formulas (`hc`, `mgmt`, `sosig`) install today. Upstream, `gists3`
and `loch` are now released with their LICENSEs, so `g3` and `loch` only need real
checksums in this tap. `mdcsv` has its LICENSE but no release yet. `social-signals`
has been restructured and relicensed, but `0.3.1` is not published. `hc` and
`media-mgmt-cli` are unchanged. Nothing in this tap has changed yet, and CI has never
run successfully. This document lists, in order, the tasks that make all six formulas
valid. Upstream state was last checked on 2026-09-24 (see
[Upstream Check](#upstream-check-2026-09-24)).

A formula is **valid** when:

1. its `url` points at an immutable upstream artifact (a tag or a published package),
2. its `license` stanza matches what the upstream repo actually declares, and
3. it passes `brew audit --strict`, `brew install --build-from-source`, and `brew test` in CI.

Most of the work happens in the upstream repos, not here. Only one upstream repo,
`social-signals`, needs structural changes; the Go and Rust layouts already match
their formulas.

## Current State

| Formula | Upstream repo | Immutable artifact | Upstream LICENSE | Formula `license` | Status |
| ------- | ------------- | ------------------ | ---------------- | ----------------- | ------ |
| `hc` | `hc` | release `v1.4.1` | GPL-3.0 text, no "or later" notice | `GPL-3.0-or-later` | Installs; license claim not backed upstream (T3.4 open) |
| `mgmt` | `media-mgmt-cli` | PyPI `0.11.0` sdist | GPL-3.0 text, `GPLv3+` classifier | `GPL-3.0-or-later` | Installs |
| `sosig` | `social-signals` | PyPI `0.3.0` wheel | GPL-3.0 + or-later notice on `main`; **none** in `0.3.0` | `MIT` | Installs; formula license wrong; `gh` undeclared; `0.3.1` unreleased |
| `g3` | `gists3` | release `v0.1.0` | MIT | `MIT` | Upstream ready; placeholder `sha256` in tap |
| `loch` | `loch` | release `v0.1.0` | GPL-3.0 + or-later notice | `GPL-3.0-or-later` | Upstream ready; placeholder `sha256` in tap |
| `mdcsv` | `mdcsv` | **none** | GPL-3.0 + or-later notice | `GPL-3.0-or-later` | Blocked: no release |

**CI is broken for all six.** Every run of `.github/workflows/audit.yml` fails at
"Set up job" with `Unable to resolve action homebrew/actions@master`. The default
branch of `Homebrew/actions` is now `main`, so no formula has passed CI yet.

## Critical Path

```text
Phase 1  Tap fixes              ─── independent, do first
Phase 2  License decisions      ─┐
Phase 3  Upstream licenses       ├── sequential: each tag must contain its LICENSE
Phase 4  Releases + checksums   ─┘
Phase 5  social-signals rework  ─── needs D1 and T3.3; otherwise independent
```

Do Phase 1 first so CI checks every later step. Phases 2–4 unblock `g3`, `loch`, and
`mdcsv`. Phase 5 removes the wheel workarounds from `sosig`, but `sosig` already
installs without it.

## Decisions

### D1: `sosig` license

`Formula/sosig.rb` says `license "MIT"`, but `social-signals` has no LICENSE file and
PyPI shows no license metadata. Without a LICENSE the code is all rights reserved,
so the tap is currently distributing it under a license that doesn't exist.

- **Option A: `GPL-3.0-or-later`.** Matches the documented default in
  [design-doc.md](design-doc.md#on-the-missing-licenses): "GPL is the default for
  tools authored here; `gists3`'s MIT is the exception." Requires changing
  `Formula/sosig.rb`.
- **Option B: `MIT`.** Matches the formula as committed; no tap change needed.

**Recommendation: A.** Follow the documented default unless there is a specific reason
to make `sosig` a second exception.

**Resolved upstream: A.** `social-signals` `7c97b25` adds the GPL-3.0 LICENSE and sets
`license = "GPL-3.0-or-later"`. `Formula/sosig.rb` still says `MIT` (T2.1).

### D2: GPL "or later" grant

Four formulas declare `GPL-3.0-or-later`. The GPL text on its own does not grant
"or later". That grant has to be stated separately, usually in a README or in source
file headers.

- `mgmt`: backed by the `GPLv3+` classifier in `pyproject.toml`.
- `hc`: **not backed.** `readme.md:108-110` says only "GNU General Public License
  v3.0". The only "any later version" text in its LICENSE is the "How to Apply These
  Terms" template at the end of the GPL, which is not a grant.
- `loch`, `mdcsv`: no license yet, so this is decided in Phase 3.

- **Option A: add an explicit "or later" notice upstream.** Keeps the formulas as they are.
- **Option B: switch `hc`, `loch`, `mdcsv` to `GPL-3.0-only`.**

**Recommendation: A.** The design doc already chose or-later, and it's a single
README paragraph per repo. **Adopted in `loch` and `mdcsv`; `hc` still pending (T3.4).**

```markdown
## License

Copyright (C) 2026 <copyright holder>

Licensed under the GNU General Public License, version 3 or (at your option) any
later version. See [LICENSE](LICENSE).
```

## Tasks

### Phase 1: Tap fixes (this repo)

- [ ] **T1.1 Fix CI.** In `.github/workflows/audit.yml:27`, change
      `Homebrew/actions/setup-homebrew@master` to `@main`.
      *Done when* all six matrix jobs get past setup, `hc`, `mgmt`, and `sosig` pass,
      and `g3`, `loch`, and `mdcsv` fail only on their placeholder checksums.
- [ ] **T1.2 Declare `sosig`'s runtime dependency on `gh`.** `sosig` runs
      `gh repo view --json stargazerCount` and `gh repo view --json owner`
      (`sosig/src/sosig/utils/gh_utils.py`). Add `depends_on "gh"` to
      `Formula/sosig.rb`. `brew audit --strict` checks the order of `depends_on`
      lines, so run it after the edit.
- [ ] **T1.3 Fix the broken README link.** `readme.md:4` links to `design-doc.md`, but
      the file lives at `docs/design-doc.md`.

### Phase 2: License decisions

- [ ] **T2.1** Resolve [D1](#d1-sosig-license). If you choose Option A, change
      `license` in `Formula/sosig.rb` to `GPL-3.0-or-later`.
      *Status:* Option A chosen upstream; the formula still says `MIT`. Change it
      together with T5.5, since the `0.3.0` wheel it currently installs has no license.
- [x] **T2.2** Resolve [D2](#d2-gpl-or-later-grant). If you choose Option B, change
      `license` in `Formula/hc.rb`, `Formula/loch.rb`, and `Formula/mdcsv.rb` to
      `GPL-3.0-only`.
      *Status:* Option A chosen; no formula change needed. `hc` still has to add the
      notice (T3.4).

### Phase 3: Upstream licenses

Each LICENSE must be committed before that repo is tagged, because the tagged
tarball is what users actually download.

- [x] **T3.1 `loch`:** add the GPL-3.0 `LICENSE`, add
      `license = "GPL-3.0-or-later"` to `[package]` in `Cargo.toml`, and add a README.
      The repo has none, and the formula's `homepage` points at the repo.
      Put the D2 notice in the README.
      *Status:* done in `09c43bb` and included in the `v0.1.0` tarball.
- [x] **T3.2 `mdcsv`:** add the GPL-3.0 `LICENSE` and put the D2 notice in `readme.md`.
      *Status:* done in `5b1fada`.
- [x] **T3.3 `social-signals`:** add a `LICENSE` according to D1, set `license` in
      `sosig/pyproject.toml` to that SPDX identifier (PEP 639), and add a license
      section to `README.md`.
      *Status:* done in `7c97b25` (`license = "GPL-3.0-or-later"`,
      `license-files = ["LICENSE"]`). Ships with T5.4.
- [ ] **T3.4 `hc`:** replace `readme.md:108-110` with the D2 notice. This takes effect
      with the next `hc` release; update the formula when that release ships.
      *Status:* not started. `origin/main` still reads
      "[GNU General Public License v3.0](LICENSE)."
- [ ] **T3.5 `media-mgmt-cli` (optional):** replace `license = {text = "GNU GPL v3.0"}`
      with `license = "GPL-3.0-or-later"`, and replace the placeholder
      `willwright@example.com` in `authors`. Both take effect with the next release.
      *Status:* not started. `origin/main` has neither change.

### Phase 4: Releases and checksums

Create **GitHub releases**, not bare tags. `livecheck`'s `:github_latest` strategy reads
the releases API, so if a repo has only a tag, `brew livecheck` reports nothing for it.
Creating a release also creates its tag:

```bash
gh release create v0.1.0 --generate-notes
```

- [x] **T4.1 `gists3`:** release `v0.1.0`. Nothing blocks this; its LICENSE is already there.
- [x] **T4.2 `loch`:** release `v0.1.0` after T3.1.
- [ ] **T4.3 `mdcsv`:** release `v0.1.0` after T3.2.
      *Status:* T3.2 is done, so nothing blocks it. No tag exists on the remote.
- [ ] **T4.4 Fill in the checksums.** Replace each placeholder `sha256` in `Formula/g3.rb`,
      `Formula/loch.rb`, and `Formula/mdcsv.rb`:

  ```bash
  curl -sL https://github.com/will-wright-eng/<repo>/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
  ```

  Checksums of the published `v0.1.0` tarballs:

  | Formula | `sha256` |
  | ------- | -------- |
  | `g3` | `9ad232157ebcdce94ea850058161bcc46bf0650eb7d1b27f136b4e9eee649929` |
  | `loch` | `f4e334bced7ec2593f1e551825604cdcc0fa96102071cc0e0bcba6853c149cab` |
  | `mdcsv` | pending T4.3 |

- [ ] **T4.5 Update the docs.** Change the three rows in the `readme.md` status table
      to "Ready", and tick off the "Blocked on the tool's own repo" items in the
      [design-doc.md setup checklist](design-doc.md#setup-checklist).

### Phase 5: `social-signals` restructure and republish

The package sits in a `sosig/` subdirectory, and `pyproject.toml` reaches outside it
twice: `readme = "../README.md"` and `testpaths = ["../tests"]`. The first one is why
the sdist can't be built.

- [x] **T5.1 Move `sosig/pyproject.toml`, `sosig/src/`, and the lockfiles to the repo
      root.** The repo contains only one package, so the subdirectory adds nothing, and
      moving it removes both `..` references. The fallback is to give `sosig/` its own
      README, but that leaves two READMEs to keep in sync.
      *Status:* done in `7c97b25`. `pyproject.toml` now uses `readme = "README.md"` and
      `testpaths = ["tests"]`. The leftover `sosig/` directory holds only untracked
      `.venv` and `.coverage`, and can be deleted.
- [x] **T5.2 Remove `pip>=24.3.1` from `dependencies`.** Nothing in `src/sosig`
      imports it.
- [x] **T5.3 Stop creating the database on import.** `src/sosig/__init__.py` calls
      `get_db()` at import time, so importing the package (including during `brew test`)
      creates `$XDG_DATA_HOME/sosig`. Move the call into the CLI entry point.
      *Status:* verified. Neither `import sosig` nor `sosig --help` creates anything
      under `$XDG_DATA_HOME`.
- [ ] **T5.4 Release `0.3.1`** to PyPI and GitHub. Before publishing, check the sdist:

  ```bash
  python -m build --sdist
  tar -tzf dist/sosig-0.3.1.tar.gz | grep -F '..'   # must print nothing
  python -m venv /tmp/sosig-check && /tmp/sosig-check/bin/pip install dist/sosig-0.3.1.tar.gz
  ```

  *Status:* not released (PyPI latest is `0.3.0`; no `v0.3.1` tag). The pre-publish
  check passes against `7c97b25`. The sdist builds, contains no `..` paths, installs,
  and reports `License-Expression: GPL-3.0-or-later`. Before tagging:

  - commit the local, uncommitted edits to `.github/workflows/publish.yml` and
    `pre-publish.yml` (`packages_dir` → `packages-dir`, `repository_url` →
    `repository-url`), plus the `README.md` and `scripts/analyze-repo-file.sh` edits
  - fix the typo in the `authors` email in `pyproject.toml`
    (`will.wright.engineeering@gmail.com` has three e's)

- [ ] **T5.5 Switch `Formula/sosig.rb` to the sdist pattern:**

  - point `url` at the sdist and drop `using: :nounzip`
  - replace the custom `install` body with `virtualenv_install_with_resources`
  - replace the hand-written `livecheck` with `url :stable` / `strategy :pypi`
  - regenerate resources with `brew update-python-resources Formula/sosig.rb`
    (`--package-name` is no longer needed)
  - keep `depends_on "rust" => :build`, since `pydantic-core` still builds from source

  Then update the `sosig` section of [design-doc.md](design-doc.md) to match.

## Upstream Check (2026-09-24)

Each repo's `origin/main`, tags, and GitHub releases were inspected, and every
published artifact was downloaded and built outside Homebrew:

| Repo | Result |
| ---- | ------ |
| `gists3` | `v0.1.0` release contains MIT `LICENSE`. `go build ./cmd/g3` succeeds; bare `g3` prints `usage: g3` and exits 2, matching the formula test. |
| `loch` | `v0.1.0` release contains GPL-3.0 `LICENSE`, `README.md` with the D2 notice, and `license = "GPL-3.0-or-later"` in `Cargo.toml`. `cargo build --release` succeeds; `loch --version` prints `loch 0.1.0`, and `--help` exits 0. |
| `mdcsv` | `main` (`5b1fada`) has GPL-3.0 `LICENSE` and the D2 notice. `go build .` succeeds and `--help` prints `usage: mdcsv`. No tag or release. |
| `social-signals` | `main` (`7c97b25`) completes T3.3 and T5.1–T5.3; the sdist check passes. `0.3.1` not released; uncommitted workflow edits locally. |
| `hc` | No change since `v1.4.1`. README still lacks the or-later grant. |
| `media-mgmt-cli` | No change to license metadata or `authors`. Only Dependabot merges since `v0.11.0`. |

These builds do not replace `brew audit --strict` or `brew install`; those still run
in CI once T1.1 lands.

## Verification

Run this for each formula locally before pushing:

```bash
brew tap will-wright-eng/tools "$(pwd)"
brew audit --strict will-wright-eng/tools/<name>
brew install --build-from-source will-wright-eng/tools/<name>
brew test will-wright-eng/tools/<name>
brew livecheck will-wright-eng/tools/<name>
brew uninstall <name>
```

Everything is done when:

- all six `audit.yml` matrix jobs pass on `main`,
- `brew livecheck` reports a current version for all six, and
- no formula's `license` stanza claims more than its upstream repo declares.

## Watch List

These don't block anything now, but will need action later.

- **`mgmt` and `awscrt`.** `media-mgmt-cli`'s `pyproject.toml` now lists
  `botocore[crt]`, but the published `0.11.0` does not. The next release will pull in
  the compiled `awscrt` package, and `Formula/mgmt.rb` will then need
  `depends_on "cmake" => :build`.
- **Design doc drift.** [design-doc.md](design-doc.md) is out of date in three places:
  - `loch`'s `rust-version` is now `1.87`, not `1.85`. Homebrew's Rust still covers it.
  - The CI section says the placeholder formulas fail at the download step; currently
    every job fails at setup (fixed by T1.1).
  - The repository structure tree shows `design-doc.md` at the root; it lives in `docs/`.

## References

- [design-doc.md](design-doc.md): formula design and the reasoning behind each choice
- [Homebrew License Guidelines](https://docs.brew.sh/License-Guidelines)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Python for Formula Authors](https://docs.brew.sh/Python-for-Formula-Authors)
- [Homebrew `brew livecheck`](https://docs.brew.sh/Brew-Livecheck): the `GithubLatest` strategy reads GitHub releases
- [Homebrew/actions](https://github.com/Homebrew/actions): `setup-homebrew`, default branch `main`
- [GNU: How to Use GNU Licenses for Your Own Software](https://www.gnu.org/licenses/gpl-howto.html): the "or later" notice
- [SPDX License List](https://spdx.org/licenses/): `GPL-3.0-or-later`, `GPL-3.0-only`, `MIT`
- [PEP 639: Licensing metadata in core metadata](https://peps.python.org/pep-0639/): `license` as an SPDX expression
- [Cargo manifest: `license` field](https://doc.rust-lang.org/cargo/reference/manifest.html#the-license-and-license-file-fields)
