# Reference copy -- the live formula is auto-managed by the release workflow
# in the reidemeister94/homebrew-tap repository (Casks/ai-usage-bar.rb).
cask "ai-usage-bar" do
  version "1.0.0"
  sha256 "REPLACED_BY_RELEASE_WORKFLOW"

  url "https://github.com/reidemeister94/ai-usage-bar/releases/download/v#{version}/AIUsageBar.app.zip"
  name "AI Usage Bar"
  desc "macOS menu bar app for tracking Claude AI usage"
  homepage "https://github.com/reidemeister94/ai-usage-bar"

  app "AIUsageBar.app"

  zap trash: [
    "~/Library/Preferences/com.ai-usage-bar.app.plist",
    "~/Library/Application Support/AIUsageBar",
  ]
end
