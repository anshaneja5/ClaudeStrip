cask "claudestrip" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/anshaneja5/ClaudeStrip/releases/download/v#{version}/ClaudeStrip.zip"
  name "ClaudeStrip"
  desc "Claude Code usage in the macOS Touch Bar Control Strip"
  homepage "https://github.com/anshaneja5/ClaudeStrip"

  depends_on macos: ">= :ventura"

  app "ClaudeStrip.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/ClaudeStrip.app"]
    system_command "#{appdir}/ClaudeStrip.app/Contents/Resources/post-install.sh"
  end

  uninstall launchctl: "app.claudestrip",
            quit:      "app.claudestrip"

  zap trash: [
    "~/Library/LaunchAgents/app.claudestrip.plist",
    "/tmp/claudestrip.log",
    "/tmp/claudestrip.err",
  ]
end
