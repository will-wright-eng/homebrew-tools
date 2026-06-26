class Hc < Formula
  desc "Find codebase hotspots by combining git churn with file complexity"
  homepage "https://github.com/will-wright-eng/hc"
  version "1.3.0"
  license "GPL-3.0-only"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/will-wright-eng/hc/releases/download/v1.3.0/hc_darwin_arm64.tar.gz"
      sha256 "fd5741c23840d38a82abaefb139b0354ce96a1fbb471da5f0ed5821644f0084b"
    end
    on_intel do
      url "https://github.com/will-wright-eng/hc/releases/download/v1.3.0/hc_darwin_amd64.tar.gz"
      sha256 "6b323dd47e26edf79d79aebfa17d4bdae8135ca3c336800568955ff6e7142e1c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/will-wright-eng/hc/releases/download/v1.3.0/hc_linux_arm64.tar.gz"
      sha256 "f6e47539927eac0dbfcc8b26561e505ea06acf9312601506a6533ea6e7b7139d"
    end
    on_intel do
      url "https://github.com/will-wright-eng/hc/releases/download/v1.3.0/hc_linux_amd64.tar.gz"
      sha256 "d41bf7fcbc3c48ef52647fc86c61a0ce9acf75323deb5cfb63c56a61673213e5"
    end
  end

  def install
    bin.install "hc"
  end

  test do
    assert_match "hc", shell_output("#{bin}/hc --help")
  end
end
