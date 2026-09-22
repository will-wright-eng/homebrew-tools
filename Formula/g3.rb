class G3 < Formula
  desc "Object storage CLI over GitHub Gists, speaking aws-cli vocabulary"
  homepage "https://github.com/will-wright-eng/gists3"
  url "https://github.com/will-wright-eng/gists3/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
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
