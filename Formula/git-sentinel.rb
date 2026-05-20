class GitSentinel < Formula
  desc "GitHub repository ruleset enforcer"
  homepage "https://github.com/beetlestance/homebrew-tap"
  url "https://github.com/beetlestance/homebrew-tap/archive/refs/tags/git-sentinel-v2.0.0.tar.gz"
  sha256 "e0198823b34ba0c6cccaa7c9a2a5c99d85f2995dd50c264ce5df188a3b0a040f"
  version "2.0.0"
  head "https://github.com/beetlestance/homebrew-tap.git", branch: "develop"
  license "GPL-3.0"

  depends_on "gh"
  depends_on "yq"
  depends_on "jq"

  def install
    bin.install "git-sentinel/bin/git-sentinel"
    chmod 0755, bin/"git-sentinel"
    # Install all lib files (*.sh helpers + sentinel.example.yml schema source)
    (lib/"git-sentinel").install Dir["git-sentinel/lib/*"]
    (share/"git-sentinel/templates").install Dir["git-sentinel/templates/*"]
  end

  test do
    assert_match "git-sentinel v", shell_output("#{bin}/git-sentinel version")
  end
end
