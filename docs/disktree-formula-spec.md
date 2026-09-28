# Spec: disktree formula for homebrew-tools

Sep 27, 2026 · @Will

## Summary

Add `Formula/disktree.rb` to the `homebrew-tools` tap so `brew install will-wright-eng/tools/disktree` builds [tobi/disktree](https://github.com/tobi/disktree) from its tagged source on macOS and puts `disktree` on the PATH.

In scope:

- A source-build formula pinned to an upstream release tag. Apple silicon Macs on macOS 14+ are supported; macOS 11–13 and Intel Macs are best effort.
- A `test do` block, `brew audit` / `brew style` passing, and `livecheck` so new releases are detected.
- `disktree` added to the `audit.yml` matrix, so it and every bump PR are audited, installed and tested in CI.
- A repeatable way to bump the formula when upstream tags a release.

Out of scope: submitting to homebrew-core, bottles, a cask, Linux, signing or notarizing, and the unrelated Swift port (`kylemclaren/tap/disktree`).

## Formula, not cask

Use a source-build formula that runs upstream's own bundler and installs both `disktree.app` and a `disktree` command. It builds from the tag, so it never depends on upstream's release zips being signed, and a locally built app carries no quarantine flag.

| Option | Installs | Needs on the Mac | Trade-off |
| --- | --- | --- | --- |
| Formula (chosen) | `disktree.app` in the keg + `bin/disktree` | Homebrew `rust` (build only), Xcode CLT | Compiles GPUI on each machine; ad-hoc signed |
| Cask | `disktree.app` in /Applications from the release zip | Nothing | Unsigned zips hit Gatekeeper; only as current as upstream's release assets |

The tap stays formula-only. It ships no downloaded binaries (see `design-doc.md`), and upstream's zips can be unsigned, which is exactly what Homebrew's Gatekeeper deprecation for casks targets.

## Tap layout

The formula lives at `Formula/disktree.rb` in the existing `will-wright-eng/homebrew-tools` GitHub repo, which Homebrew addresses as the tap `will-wright-eng/tools`.

```
homebrew-tools/
├── Formula/
│   ├── disktree.rb        (new)
│   └── g3.rb, hc.rb, loch.rb, mdcsv.rb, mgmt.rb, sosig.rb
└── .github/
    ├── scripts/bump_formula.py
    └── workflows/
        ├── audit.yml      (disktree added to the matrix)
        └── livecheck.yml
```

Users install it with:

```bash
brew install will-wright-eng/tools/disktree   # taps automatically on first use
# or
brew tap will-wright-eng/tools && brew install disktree
```

Develop from the repo checkout with `brew tap will-wright-eng/tools "$(pwd)"`, so local edits are what `brew install` builds.

## Formula design

The formula mirrors upstream's macOS `make install`: run `cargo xtask bundle`, then install the app and link its binary, with Homebrew's keg in place of `~/Applications` and `~/.local/bin`.

| Field | Value | Why |
| --- | --- | --- |
| `url` | `https://github.com/tobi/disktree/archive/refs/tags/v0.10.1.tar.gz` | Latest tag as of today; `main` already says 0.10.1 in Cargo.toml |
| `sha256` | `d4f643b578799d0a4f702b64cfa6f180110280cbd8e02d14f7178efe0709f7ce` | Computed from that tarball |
| `license` | `"MIT"` | Upstream LICENSE |
| `head` | `https://github.com/tobi/disktree.git`, branch `main` | Allows `--HEAD` builds |
| Build dependency | `rust` (Homebrew stable is 1.98.1) | Workspace sets `rust-version = "1.97"` |
| Platform | `depends_on :macos` | App bundle is macOS 11+, already Homebrew's floor (`brew style` rejects `macos: :big_sur` as redundant); Linux needs Vulkan/Wayland libs, out of scope |

Build steps, all taken from the repo:

1. `cargo xtask bundle` (an alias in `.cargo/config.toml`). It runs `cargo build --release --locked -p disktree-app` with the macOS 11 deployment target, strips the binary, writes Info.plist, draws the icon with `sips` and `iconutil`, and ad-hoc signs with `codesign`. Output: `target/bundle/disktree.app`.
2. `prefix.install "target/bundle/disktree.app"`.
3. `bin.install_symlink` to `disktree.app/Contents/MacOS/disktree`, the same symlink upstream's Makefile makes.

All of those tools ship with macOS or the Command Line Tools, so no further dependencies are declared. GPUI needs no Metal compiler either: `gpui-kit` 0.6.6 enables `runtime_shaders` on macOS, so shaders compile when the app starts, and `gpui-pre-apple`'s build script never calls `xcrun metal`. If a future `gpui-kit` drops that feature, the build will need full Xcode (`depends_on xcode: :build`). The bump PR's CI run won't catch it, because GitHub's macOS runners have Xcode installed.

## Draft formula

`Formula/disktree.rb`, ready to commit once the tests below pass:

```ruby
class Disktree < Formula
  desc "Treemap for finding and removing what fills your disk"
  homepage "https://github.com/tobi/disktree"
  url "https://github.com/tobi/disktree/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "d4f643b578799d0a4f702b64cfa6f180110280cbd8e02d14f7178efe0709f7ce"
  license "MIT"
  head "https://github.com/tobi/disktree.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build
  depends_on :macos

  def install
    # Upstream's bundler: release build (--locked), strip, Info.plist,
    # icon via sips/iconutil, ad-hoc codesign -> target/bundle/disktree.app
    system "cargo", "xtask", "bundle"
    prefix.install "target/bundle/disktree.app"
    bin.install_symlink prefix/"disktree.app/Contents/MacOS/disktree"
  end

  def caveats
    <<~EOS
      disktree.app is in:
        #{opt_prefix}/disktree.app
      To open it from Finder's Applications folder or the Dock, link it
      into ~/Applications:
        ln -sf #{opt_prefix}/disktree.app ~/Applications/disktree.app
      Spotlight does not list a symlinked app; run `disktree` instead.

      For a complete scan, grant Full Disk Access in System Settings >
      Privacy & Security to disktree, or to your terminal if you run
      `disktree` from it. The build is ad-hoc signed, so macOS may ask
      again after an upgrade.
    EOS
  end

  test do
    assert_match "usage: disktree", shell_output("#{bin}/disktree --help")
  end
end
```

The test relies on `--help` printing usage and exiting before any window opens, which `parse_args` in `crates/disktree-app/src/main.rs` does.

## Testing

The formula ships when a clean from-source install, `brew test` and a strict audit all pass on an Apple silicon Mac, and in CI. `audit.yml` gains `disktree` in its `formula` matrix, which also gates every bump PR that `livecheck.yml` opens.

```bash
brew tap will-wright-eng/tools "$(pwd)"
brew install --build-from-source --verbose will-wright-eng/tools/disktree
brew test will-wright-eng/tools/disktree
brew audit --strict --online will-wright-eng/tools/disktree
brew style will-wright-eng/tools
```

Then check by hand:

- [ ] `codesign --verify --deep --strict "$(brew --prefix disktree)/disktree.app"` succeeds.
- [ ] `disktree ~/Downloads` opens the window and scans.
- [ ] The app opens from Finder after the `~/Applications` symlink in the caveats.
- [ ] `brew install --HEAD will-wright-eng/tools/disktree` builds from `main`.
- [ ] `brew uninstall disktree` leaves nothing in the prefix.

## Release updates

Upstream tags often (v0.9.0 to v0.10.1 within days). The tap's existing `livecheck.yml` covers `disktree` without changes: on the 1st of each month it runs `brew livecheck`, `bump_formula.py` rewrites the archive `url` and `sha256`, and a `chore(disktree): bump disktree to <version>` PR opens and is audited by `audit.yml`. To pick up a release sooner, dispatch it by hand:

```bash
gh workflow run livecheck.yml
```

Or bump by hand on a branch and open a PR so CI gates it:

```bash
brew livecheck will-wright-eng/tools/disktree        # is there a newer tag?
brew bump-formula-pr --write-only \
  --version 0.10.2 will-wright-eng/tools/disktree   # rewrites url + sha256
git switch -c bump/disktree-0.10.2
git commit -am 'chore(disktree): bump disktree to 0.10.2'
gh pr create --fill
```

No bottles. They would mean adopting `brew test-bot` with `tests.yml` / `publish.yml`, which `design-doc.md` deliberately passed over in favor of explicit audit, install and test steps. Bottle pour also relocates and re-signs patched Mach-O files, and whether that keeps the `.app`'s sealed signature valid is unverified. Revisit if install time matters to more than one or two users.

## Risks

| Risk | Effect | Mitigation |
| --- | --- | --- |
| Ad-hoc signature changes every build | Full Disk Access and folder prompts may be asked again after each upgrade | Documented in caveats; a Developer ID signature would fix it but is out of scope |
| Upstream raises its MSRV past Homebrew's `rust` | Build fails until Homebrew bumps Rust | Homebrew's build env has no rustup, so `rust-toolchain.toml` (1.97) is ignored; watch `rust-version` in Cargo.toml when bumping |
| No Rust bottle for the machine | Homebrew's `rust` has bottles only for Apple silicon on macOS 14+ and Linux, so Intel Macs and macOS 11–13 compile Rust before disktree | Treat those as best effort; supported and tested is Apple silicon on macOS 14+ |
| Cargo fetches crates during build | No offline installs; first build takes minutes | None for now; revisit bottles (Release updates) if install time matters |
| Homebrew can't install into /Applications | App isn't in /Applications, and Spotlight doesn't index a symlinked app | `~/Applications` symlink in caveats covers Finder and the Dock; Spotlight users run `disktree` |

## Acceptance criteria

- [ ] `Formula/disktree.rb` merged to `main` of `homebrew-tools`.
- [ ] `disktree` is in the `audit.yml` matrix, and its audit, install and test jobs pass.
- [ ] `brew install will-wright-eng/tools/disktree` succeeds on a clean Apple silicon Mac on macOS 14+ with only Homebrew and the CLT.
- [ ] `brew test` and `brew audit --strict --online` pass.
- [ ] `brew livecheck` reports the latest upstream tag.
- [ ] `readme.md` (install line and Tools table), `design-doc.md` (inventory, repository structure, and a short disktree section noting it is the tap's first third-party formula and first GUI app) and `formula-readiness.md` list `disktree`.

## Sources

- [tobi/disktree README](https://github.com/tobi/disktree), plus its Makefile, Cargo.toml, `xtask/src/bundle.rs` and tags, read from a clone of `main`
- `gpui-kit` 0.6.6 `Cargo.toml` and `gpui-pre-apple` 0.3.6 `build.rs` from crates.io, and `cargo tree -e features` on the disktree workspace, for `runtime_shaders`
- [Homebrew `rust` formula](https://formulae.brew.sh/formula/rust) and its [API JSON](https://formulae.brew.sh/api/formula/rust.json) for bottle platforms
- [Homebrew discussion on pinned Rust in taps](https://github.com/orgs/Homebrew/discussions/6608)
- [design-doc.md](design-doc.md): the tap's formula-only, source-build and CI decisions
