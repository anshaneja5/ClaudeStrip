cask "claudestrip" do
  version "0.1.1"
  sha256 "c3d81451e8017669ad423e25a733ca8b95fe1b9af8141f225b7f800d545498fa"

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
