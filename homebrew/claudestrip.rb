cask "claudestrip" do
  version "0.3.0"
  sha256 "10a90fbe6b5c8e957e987c657cb13dafcea0b59c998f12709cdd9ff4cc86f28a"

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

  preflight do
    # Run the bundled uninstaller (removes LaunchAgent) before the app is deleted.
    uninstall_script = "#{appdir}/ClaudeStrip.app/Contents/Resources/uninstall.sh"
    system_command uninstall_script if File.exist?(uninstall_script)
  end

  uninstall launchctl: "app.claudestrip",
            quit:      "app.claudestrip"

  zap trash: [
    "~/Library/LaunchAgents/app.claudestrip.plist",
    "/tmp/claudestrip.log",
    "/tmp/claudestrip.err",
  ]
end
