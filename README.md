# ClaudeStrip

Claude Code usage, live in your MacBook Pro Touch Bar Control Strip.

Shows — and cycles on tap — four metrics drawn entirely from your local
`~/.claude` data:

- 💵 **Today's cost** (`$4.21`)
- ⚡ **Rate limits** (`⚡ 5h 62% 7d 18%`)
- 🔢 **Tokens today** (`1.2M tok`)
- ▶️ **Live session cost** (`▶ $0.84`)

100% local. No hooks, no Claude Code config changes, nothing leaves your
machine. The analytics engine is reused from
[Claude-Guardian](https://github.com/anshaneja5/Claude-Guardian).

## How it works

A menubar-agent app watches `~/.claude` and parses session `.jsonl` files for
token usage and cost (with per-model pricing), plus the rolling 5h/7d
rate-limit snapshots. It pins one item into the Touch Bar Control Strip (via
private DFR APIs, the same approach Pock uses) so the current metric is always
visible. Tap to cycle metrics. The "active" session is the
most-recently-modified session file. A menubar item mirrors the value and
provides Quit.

## Install

### Homebrew

```bash
brew install --cask anshaneja5/tap/claudestrip
```

> Gatekeeper (unsigned app): if macOS blocks first launch, run
> `xattr -cr /Applications/ClaudeStrip.app` once, then reopen.

### From source

```bash
git clone https://github.com/anshaneja5/ClaudeStrip.git
cd ClaudeStrip
./run-tests.sh     # run unit tests (via swiftc — no SwiftPM needed)
./build-app.sh     # produces build/ClaudeStrip.app
open build/ClaudeStrip.app
```

## Requirements

- macOS 13+ (Ventura or later)
- A MacBook Pro with a Touch Bar
- Swift 5.9+ (Xcode or Command Line Tools)

## Uninstall

Homebrew: `brew uninstall --cask claudestrip`
From source: `./uninstall.sh`

## Notes & limitations

- Uses **private/undocumented APIs** for the Control Strip — not App Store
  eligible, and a future macOS could break it. If registration fails, the
  value still shows in the menubar.
- Refresh is debounced (~1.5s after Claude writes).
- "Active session" is inferred from file modification time.

## Development notes

- **Tests** run via `./run-tests.sh`, which compiles `ClaudeStrip/Sources/Core`
  plus `Tests/main.swift` with `swiftc` and runs the assertions. This avoids
  SwiftPM, which is broken in some Command Line Tools installs.
- The shipped app is built by `./build-app.sh` with `swiftc` directly,
  importing the private `DFRFoundation` framework via
  `ClaudeStrip/App/DFR-Bridging-Header.h`.
- Core logic (`UsageSnapshot`, `Metric`, `ActiveSession`) is Foundation-only
  and unit-tested; the AppKit layer is verified by running the app.
```
