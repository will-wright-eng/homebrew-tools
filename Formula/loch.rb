class Loch < Formula
  desc "Per-commit LOC history via gix and tokei, without a working tree"
  homepage "https://github.com/will-wright-eng/loch"
  url "https://github.com/will-wright-eng/loch/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "GPL-3.0-or-later"
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
