class GitSentinel < Formula
  desc "GitHub repository ruleset enforcer"
  homepage "https://github.com/beetlestance/homebrew-tap"
  url "https://github.com/beetlestance/homebrew-tap/releases/download/git-sentinel-v3.0.2/git-sentinel-3.0.2.tar.gz"
  sha256 "44ab1312a97a73ee01f2330843227926a0f1f639759b0c2629bc47dfe04384dd"
  version "3.0.2"
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
