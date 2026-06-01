#!/bin/bash
set -e

PLIST="$HOME/Library/LaunchAgents/app.claudestrip.plist"
APP="/Applications/ClaudeStrip.app/Contents/MacOS/ClaudeStrip"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>app.claudestrip</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claudestrip.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claudestrip.err</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "ClaudeStrip installed and launched."
