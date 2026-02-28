cask "ai-usage-bar" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/YOUR_USER/ai-usage-bar/releases/download/v#{version}/AIUsageBar.app.zip"
  name "AI Usage Bar"
  desc "macOS menu bar app for tracking Claude AI usage"
  homepage "https://github.com/YOUR_USER/ai-usage-bar"

  app "AIUsageBar.app"

  zap trash: [
    "~/Library/Preferences/com.ai-usage-bar.app.plist",
    "~/Library/Application Support/AIUsageBar",
  ]
end
