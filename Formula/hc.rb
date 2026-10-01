class Hc < Formula
  desc "Hot/cold codebase analysis: git churn crossed with file complexity"
  homepage "https://github.com/will-wright-eng/hc"
  url "https://github.com/will-wright-eng/hc/archive/refs/tags/v1.4.2.tar.gz"
  sha256 "0de3c8babbb56f98adfe7d4648966eda0db34808ac5b145133c0250300345ab7"
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
