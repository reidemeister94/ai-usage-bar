# Reference copy -- the live formula is auto-managed by the release workflow
# in the reidemeister94/homebrew-tap repository (Formula/ai-usage-bar.rb).
class AiUsageBar < Formula
  desc "macOS menu bar app for tracking Claude AI usage"
  homepage "https://github.com/reidemeister94/ai-usage-bar"
  url "https://github.com/reidemeister94/ai-usage-bar/releases/download/v1.1.0/ai-usage-bar"
  sha256 "REPLACED_BY_RELEASE_WORKFLOW"
  license "MIT"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  def install
    bin.install "ai-usage-bar"
  end
end
