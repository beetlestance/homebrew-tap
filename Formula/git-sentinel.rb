class GitSentinel < Formula
  desc "GitHub repository ruleset enforcer"
  homepage "https://github.com/beetlestance/homebrew-tap"
  head "https://github.com/beetlestance/homebrew-tap.git", branch: "develop"
  license "GPL-3.0"

  depends_on "gh"
  depends_on "yq"
  depends_on "jq"

  def install
    bin.install "git-sentinel/bin/git-sentinel"
    # Install all lib files (*.sh helpers + sentinel.example.yml schema source)
    (lib/"git-sentinel").install Dir["git-sentinel/lib/*"]
    (share/"git-sentinel/templates").install Dir["git-sentinel/templates/*"]
  end

  test do
    assert_match "git-sentinel v", shell_output("#{bin}/git-sentinel version")
  end
end
