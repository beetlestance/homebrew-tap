class GitSentinel < Formula
  desc "GitHub repository ruleset enforcer"
  homepage "https://github.com/beetlestance/homebrew-tap"
  url "https://github.com/beetlestance/homebrew-tap/archive/refs/tags/git-sentinel-v1.0.0.tar.gz"
  sha256 "dbf3342fc8bc3a4e90e8aa2ad990cac1a5fe1ea6336fe109971a8597072c2617"
  license "GPL-3.0"
  version "1.0.0"

  depends_on "gh"
  depends_on "yq"
  depends_on "jq"

  def install
    bin.install "git-sentinel/bin/git-sentinel"
    (lib/"git-sentinel").install Dir["git-sentinel/lib/*.sh"]
    (share/"git-sentinel/templates").install Dir["git-sentinel/templates/*"]
  end

  test do
    assert_match "git-sentinel v#{version}", shell_output("#{bin}/git-sentinel version")
  end
end
