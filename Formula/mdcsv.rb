class Mdcsv < Formula
  desc "Convert between markdown tables and CSV"
  homepage "https://github.com/will-wright-eng/mdcsv"
  url "https://github.com/will-wright-eng/mdcsv/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "58312bb73857854da2cae69d4aa741919462d87604e87d27a3ee582cb22b9c25"
  license "GPL-3.0-or-later"
  head "https://github.com/will-wright-eng/mdcsv.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: :goreleaser), "."
  end

  test do
    assert_match "usage: mdcsv", shell_output("#{bin}/mdcsv --help")
    assert_match version.to_s, shell_output("#{bin}/mdcsv --version")
  end
end
