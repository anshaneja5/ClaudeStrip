#!/bin/bash
PLIST="$HOME/Library/LaunchAgents/app.claudestrip.plist"

pkill -f "ClaudeStrip.app/Contents/MacOS/ClaudeStrip" 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -f /tmp/claudestrip.log /tmp/claudestrip.err
echo "ClaudeStrip uninstalled (app bundle not removed; delete it from /Applications if desired)."
