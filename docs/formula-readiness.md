# Formula Readiness

## Summary

All six formulas pass `brew audit --strict`, `brew install --build-from-source`, and
`brew test` in CI (run `36188539028`, 2026-09-25). `g3`, `loch`, and `mdcsv` are
complete. Three formulas still have work left:

- **`hc`:** upstream published `v1.4.2`, which carries the or-later notice; the formula
  still installs `v1.4.1` (T4.6).
- **`sosig`:** installs the `0.3.0` wheel under a wrong `MIT` license; the `0.3.1` sdist
  is ready to switch to (T2.1 + T5.5).
- **`mgmt`:** installs and is correctly licensed, but upstream's `0.12.0` never reached
  PyPI (T3.5).

A monthly livecheck workflow now opens bump PRs automatically, but it can't create
PRs until the repo allows Actions to (T6.1). The remaining work is otherwise docs, repo
hardening, and upstream housekeeping. Upstream state was last checked on 2026-09-25
(see [Upstream Check](#upstream-check-2026-09-25)).

A formula is **valid** when:

1. its `url` points at an immutable upstream artifact (a tag or a published package),
2. its `license` stanza matches what the upstream repo actually declares, and
3. it passes `brew audit --strict`, `brew install --build-from-source`, and `brew test` in CI.

## Current State

| Formula | Upstream repo | Formula installs | Latest upstream | Upstream LICENSE | Formula `license` | Status |
| ------- | ------------- | ---------------- | --------------- | ---------------- | ----------------- | ------ |
| `g3` | `gists3` | `v0.1.0` | `v0.1.0` | MIT | `MIT` | **Valid** |
| `loch` | `loch` | `v0.1.0` | `v0.1.0` | GPL-3.0 + or-later notice | `GPL-3.0-or-later` | **Valid** |
| `mdcsv` | `mdcsv` | `v0.1.0` | `v0.1.0` | GPL-3.0 + or-later notice | `GPL-3.0-or-later` | **Valid** |
| `hc` | `hc` | `v1.4.1` | `v1.4.2` | GPL-3.0; or-later notice from `v1.4.2` | `GPL-3.0-or-later` | Outdated; license claim backed only after T4.6 |
| `sosig` | `social-signals` | `0.3.0` wheel | `0.3.1` sdist + wheel | GPL-3.0 + or-later notice from `0.3.1` | `MIT` | Outdated; **license wrong** (T2.1) |
| `mgmt` | `media-mgmt-cli` | PyPI `0.11.0` sdist | PyPI `0.11.0` | GPL-3.0, `GPLv3+` classifier | `GPL-3.0-or-later` | **Valid**; upstream `0.12.0` unpublished (T3.5) |

### CI

| Workflow | Trigger | State |
| -------- | ------- | ----- |
| `audit.yml` | push/PR touching `Formula/**`, manual dispatch | Passing on `main` for all six formulas |
| `livecheck.yml` | 1st of each month 14:00 UTC, manual dispatch | Not yet run; PR creation blocked until T6.1 |

`livecheck.yml` runs `brew livecheck --tap will-wright-eng/tools --json`, then
`.github/scripts/bump_formula.py` rewrites `url` and `sha256` for each outdated formula
(and regenerates Python resources). The workflow pushes a `livecheck/bump` branch,
opens or updates a PR, and dispatches `audit.yml` against that branch, because pushes
made with `GITHUB_TOKEN` don't trigger other workflows. A livecheck error fails the job.

Its first run will propose `hc` → `1.4.2` and `sosig` → the `0.3.1` **wheel**. Do
T5.5 first so the bot bumps the sdist-based formula instead.

## Remaining Work

In suggested order. Details are under [Tasks](#tasks).

| # | Task | Where | Blocked by |
| - | ---- | ----- | ---------- |
| 1 | **T6.1** Allow Actions to create PRs | repo settings | — |
| 2 | **T6.2–T6.5** Harden the repo | repo settings | — |
| 3 | **T6.6** Merge Dependabot PR #2 (`actions/checkout` → `v7.0.1`) | this repo | — |
| 4 | **T4.6** Move `hc` to `v1.4.2` | this repo | — |
| 5 | **T2.1 + T5.5** Move `sosig` to the `0.3.1` sdist, license `GPL-3.0-or-later` | this repo | — |
| 6 | **T4.5** Update the `hc` and `sosig` sections of the docs | this repo | 4, 5 |
| 7 | **T3.5** Publish `mgmt` `0.12.1` to PyPI, then bump the formula | `media-mgmt-cli`, then this repo | — |
| 8 | **T5.6** Fix the `social-signals` release tag, author email, leftover `sosig/` dir | `social-signals` | — |
| 9 | **T6.7** Enable immutable releases upstream | all six upstream repos | 7, 8 |

## Critical Path

```text
Phase 1  Tap fixes              ─── done
Phase 2  License decisions      ─┐
Phase 3  Upstream licenses       ├── done except T2.1 (with T5.5) and T3.5
Phase 4  Releases + checksums   ─┘   remaining: T4.5, T4.6
Phase 5  social-signals rework  ─── remaining: T5.5, T5.6
Phase 6  Repo hardening         ─── independent; T6.1 unblocks livecheck PRs
```

## Decisions

### D1: `sosig` license

**Resolved: `GPL-3.0-or-later`.** This follows the default in
[design-doc.md](design-doc.md#licenses): GPL for tools authored here,
with `gists3`'s MIT as the exception. `social-signals` `7c97b25` adds the GPL-3.0
LICENSE and sets `license = "GPL-3.0-or-later"`. `Formula/sosig.rb` still says `MIT`
(T2.1).

### D2: GPL "or later" grant

The GPL text on its own does not grant "or later"; that has to be stated separately.
**Resolved: add an explicit notice upstream** rather than switching formulas to
`GPL-3.0-only`. Adopted in `loch`, `mdcsv`, and `hc` (from `v1.4.2`). `mgmt` is backed
by its `GPLv3+` classifier and SPDX `license` field; `sosig` by its SPDX `license` field
from `0.3.1`.

```markdown
## License

Copyright (C) 2026 <copyright holder>

Licensed under the GNU General Public License, version 3 or (at your option) any
later version. See [LICENSE](LICENSE).
```

## Tasks

### Phase 1: Tap fixes (this repo)

- [x] **T1.1 Fix CI.** `setup-homebrew` moved from `@master` to a SHA-pinned release
      (`2026.09.21.1`), and the manual `brew tap <path>` step was removed, because
      `setup-homebrew` already symlinks a `homebrew-*` checkout into `Library/Taps`.
      All six matrix jobs pass (run `36188539028`).
- [x] **T1.2 Declare `sosig`'s runtime dependency on `gh`.**
- [x] **T1.3 Fix the broken README link.**

### Phase 2: License decisions

- [ ] **T2.1** Change `license` in `Formula/sosig.rb` to `GPL-3.0-or-later`. Do it in
      the same change as T5.5, since the `0.3.0` wheel it currently installs has no license.
- [x] **T2.2** D2 resolved with Option A; no formula change needed.

### Phase 3: Upstream licenses

- [x] **T3.1 `loch`:** LICENSE, `Cargo.toml` `license`, and README with the D2 notice (`09c43bb`).
- [x] **T3.2 `mdcsv`:** LICENSE and D2 notice (`5b1fada`).
- [x] **T3.3 `social-signals`:** LICENSE and PEP 639 `license` (`7c97b25`).
- [x] **T3.4 `hc`:** D2 notice (`a8d76db`), shipped in `v1.4.2`.
- [ ] **T3.5 `media-mgmt-cli`:** `ccbef60` fixes the license metadata and author email,
      and a `v0.12.0` GitHub release exists, but `pyproject.toml` at that tag still says
      `version = "0.11.0"`. The publish tried to re-upload `0.11.0` and PyPI rejected
      it, so PyPI's latest is still `0.11.0`. To finish:
      1. bump `version` to `0.12.1` and cut a `v0.12.1` release (don't move the
         `v0.12.0` tag; see T6.7),
      2. confirm the publish workflow uploads `0.12.1`,
      3. let livecheck open the bump PR, or bump by hand; either way, add
         `depends_on "cmake" => :build` for `awscrt` (see [Watch List](#watch-list)).

### Phase 4: Releases and checksums

- [x] **T4.1–T4.3** `gists3`, `loch`, `mdcsv` released as `v0.1.0` (published as Latest).
- [x] **T4.4** Checksums pinned and re-verified against the published tarballs:

  | Formula | `sha256` |
  | ------- | -------- |
  | `g3` | `9ad232157ebcdce94ea850058161bcc46bf0650eb7d1b27f136b4e9eee649929` |
  | `loch` | `f4e334bced7ec2593f1e551825604cdcc0fa96102071cc0e0bcba6853c149cab` |
  | `mdcsv` | `356fef732a661ae61b02bc33af44bfa26d7a496c28e0a4c4287134f779323953` |

- [ ] **T4.5 Refresh the docs.** `readme.md` and `design-doc.md` now reflect the
      tagged formulas, upstream licenses, repo layout, and both workflows. Left:
  - after T4.6: `hc` version in `readme.md`, and the `hc` snippet, `sha256` note, and
    Tool Inventory row in `design-doc.md`.
  - after T5.5: `sosig` version in `readme.md`; in `design-doc.md`, rewrite the `sosig`
    section around the sdist pattern, update its `livecheck` note and Versioning
    Strategy row, and tick the last `social-signals` item in the Setup Checklist.
- [ ] **T4.6 Move `hc` to `v1.4.2`.** Upstream published `v1.4.2` as Latest. Update
      `url` and `sha256` in `Formula/hc.rb`, or merge the first livecheck PR:

  ```text
  url    https://github.com/will-wright-eng/hc/archive/refs/tags/v1.4.2.tar.gz
  sha256 0de3c8babbb56f98adfe7d4648966eda0db34808ac5b145133c0250300345ab7
  ```

### Phase 5: `social-signals` restructure and republish

- [x] **T5.1** Package moved to the repo root (`7c97b25`).
- [x] **T5.2** `pip` removed from `dependencies`.
- [x] **T5.3** Database no longer created on import.
- [x] **T5.4** `0.3.1` published to PyPI from `c9a2d66`; sdist has no `..` paths and
      declares `License-Expression: GPL-3.0-or-later`.
- [ ] **T5.5 Switch `Formula/sosig.rb` to the sdist pattern:**

  - point `url` at the sdist and drop `using: :nounzip`
  - replace the custom `install` body with `virtualenv_install_with_resources`
  - replace the hand-written `livecheck` with `url :stable` / `strategy :pypi`
  - regenerate resources with `brew update-python-resources Formula/sosig.rb`
  - keep `depends_on "rust" => :build`, since `pydantic-core` still builds from source
  - remove the wheel-workaround comments

  Do T2.1 in the same change. The `0.3.1` sdist:

  ```text
  url    https://files.pythonhosted.org/packages/4f/b7/bf2c3edb703b96de1d908744678a79ee226707bb3055dc7ffd7eee18f072/sosig-0.3.1.tar.gz
  sha256 d39a1972cecb59b3cdd6c81ce750318dfb588ec5f14f6d78f9142ba482e00b7d
  ```

- [ ] **T5.6 Upstream housekeeping (non-blocking):**
  - The GitHub release is tagged `v0.4.0`, but the package is `0.3.1`. The formula's
    livecheck reads PyPI, so it isn't affected. Either publish `0.4.0` to PyPI so they
    match, or replace the release with a `v0.3.1` one.
  - Fix the `authors` email typo (`will.wright.engineeering@gmail.com`, three e's) in
    the next release.
  - Delete the leftover `sosig/` directory (untracked `.venv` and `.coverage`).

### Phase 6: Repo hardening (this repo's settings)

The repo is public. Controls already in place:

- a `main` ruleset that blocks deletion and force-pushes and requires a PR with one approval
  (admins can bypass)
- default workflow permissions set to `read`
- secret scanning with push protection
- no repository secrets
- auto-merge disabled
- every action pinned to a commit SHA, with Dependabot keeping the pins current

`livecheck.yml` checks out with `persist-credentials: false` and passes the token only
to the push, so `brew` and the bump script never see it.

- [ ] **T6.1 Allow Actions to create PRs.** Required for `livecheck.yml`. The same
      setting also lets Actions approve PRs, so no workflow with `pull-requests: write`
      may run on untrusted input (no `pull_request_target`).

  ```bash
  gh api -X PUT repos/will-wright-eng/homebrew-tools/actions/permissions/workflow \
    -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
  ```

- [ ] **T6.2 Restrict which actions can run, and require SHA pinning.** Currently all
      actions are allowed. `setup-homebrew` is a Node action with no nested `uses:`, so
      requiring pins won't break it.

  ```bash
  gh api -X PUT repos/will-wright-eng/homebrew-tools/actions/permissions \
    -F enabled=true -f allowed_actions=selected -F sha_pinning_required=true
  gh api -X PUT repos/will-wright-eng/homebrew-tools/actions/permissions/selected-actions \
    -F github_owned_allowed=true -F verified_allowed=false -f 'patterns_allowed[]=Homebrew/actions/*'
  ```

- [ ] **T6.3 Require approval before running workflows from any outside contributor.**
      Currently only first-time contributors need approval. A fork PR that edits a
      formula runs arbitrary build code on the runner.

  ```bash
  gh api -X PUT repos/will-wright-eng/homebrew-tools/actions/permissions/fork-pr-contributor-approval \
    -f approval_policy=all_external_contributors
  ```

- [ ] **T6.4 Enable Dependabot alerts, security updates, and private vulnerability reporting.**

  ```bash
  gh api -X PUT repos/will-wright-eng/homebrew-tools/vulnerability-alerts
  gh api -X PUT repos/will-wright-eng/homebrew-tools/automated-security-fixes
  gh api -X PUT repos/will-wright-eng/homebrew-tools/private-vulnerability-reporting
  ```

- [ ] **T6.5 Delete branches automatically after merge**, so `livecheck/bump` starts
      clean each time.

  ```bash
  gh api -X PATCH repos/will-wright-eng/homebrew-tools -F delete_branch_on_merge=true
  ```

- [ ] **T6.6 Merge Dependabot PR #2** (`actions/checkout` `v4.4.0` → `v7.0.1`). Its
      audit run passed. It was opened before `livecheck.yml` existed, so confirm that
      the rebased PR also bumps the pin there.
- [ ] **T6.7 Enable immutable releases in the six upstream repos.** Every formula pins
      the checksum of a tag's tarball, so a moved tag breaks installs. Turn this on
      after T3.5 and T5.6, which may still need to replace releases.

Keep bot PRs manual-merge only. The required approval is the only human check between
an upstream release and users of the tap.

Not recommended:

- **Required status checks on the ruleset:** `audit.yml` is path-filtered, so PRs that
  don't touch `Formula/**` would wait forever for checks that never run.
- **CODEOWNERS:** it adds nothing with a single maintainer.

## Upstream Check (2026-09-25)

| Repo | Result |
| ---- | ------ |
| `gists3` | `v0.1.0` Latest; MIT `LICENSE`; tarball checksum matches the formula. |
| `loch` | `v0.1.0` Latest; GPL-3.0 `LICENSE`, D2 notice, `license = "GPL-3.0-or-later"`; tarball checksum matches. |
| `mdcsv` | `v0.1.0` Latest (tag at `5b1fada`); GPL-3.0 `LICENSE` and D2 notice; tarball checksum matches. |
| `hc` | `v1.4.2` published as Latest; tarball checksum `0de3c8ba…`. Formula still on `v1.4.1`. |
| `social-signals` | PyPI `0.3.1` (sdist + wheel). GitHub release still tagged `v0.4.0`; author email typo still present. |
| `media-mgmt-cli` | `v0.12.0` Latest on GitHub, but `pyproject.toml` on `main` still says `0.11.0`; PyPI latest is `0.11.0`. |

`brew livecheck --tap will-wright-eng/tools` returns a version for all six formulas with
no errors; `hc` and `sosig` report as outdated.

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

- [x] all six `audit.yml` matrix jobs pass on `main`,
- [x] `brew livecheck` reports a version for all six, without errors,
- [ ] no formula is behind upstream (`hc`, `sosig` remain),
- [ ] no formula's `license` stanza claims more than its upstream repo declares (`sosig`
      remains), and
- [ ] `livecheck.yml` has run on schedule and opened a PR that passes `audit.yml`.

## Watch List

These don't block anything now, but will need action later.

- **`mgmt` and `awscrt`.** Upstream `pyproject.toml` lists `botocore[crt]`, which the
  published `0.11.0` does not. Once T3.5's release reaches PyPI, it will pull in the
  compiled `awscrt` package, and the bump will need `depends_on "cmake" => :build`
  in addition to the regenerated resources. The livecheck bot regenerates resources but
  won't add build dependencies, so expect its first `mgmt` PR to fail `audit.yml` until
  that line is added.
- **Python resource cooldown.** `bump_formula.py` passes
  `--ignore-main-package-cooldown` so a just-published release can be bumped, but the
  formula's dependencies still respect Homebrew's release cooldown.

## References

- [design-doc.md](design-doc.md): formula design and the reasoning behind each choice
- [Homebrew License Guidelines](https://docs.brew.sh/License-Guidelines)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Python for Formula Authors](https://docs.brew.sh/Python-for-Formula-Authors)
- [Homebrew `brew livecheck`](https://docs.brew.sh/Brew-Livecheck): the `GithubLatest` strategy reads GitHub releases
- [Homebrew/actions](https://github.com/Homebrew/actions): `setup-homebrew`
- [GitHub: Triggering a workflow from a workflow](https://docs.github.com/en/actions/using-workflows/triggering-a-workflow#triggering-a-workflow-from-a-workflow): `GITHUB_TOKEN` events don't start new runs, except `workflow_dispatch`
- [GitHub: Immutable releases](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases)
- [zizmor audits](https://docs.zizmor.sh/audits/): `artipacked` and credential persistence
- [GNU: How to Use GNU Licenses for Your Own Software](https://www.gnu.org/licenses/gpl-howto.html): the "or later" notice
- [SPDX License List](https://spdx.org/licenses/): `GPL-3.0-or-later`, `GPL-3.0-only`, `MIT`
- [PEP 639: Licensing metadata in core metadata](https://peps.python.org/pep-0639/): `license` as an SPDX expression
- [Cargo manifest: `license` field](https://doc.rust-lang.org/cargo/reference/manifest.html#the-license-and-license-file-fields)
