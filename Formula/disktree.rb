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
