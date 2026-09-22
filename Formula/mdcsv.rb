class Mdcsv < Formula
  desc "Convert between markdown tables and CSV"
  homepage "https://github.com/will-wright-eng/mdcsv"
  url "https://github.com/will-wright-eng/mdcsv/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "GPL-3.0-or-later"
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
