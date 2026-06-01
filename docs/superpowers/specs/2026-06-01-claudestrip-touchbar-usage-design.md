# ClaudeStrip — Claude Code usage in the macOS Touch Bar Control Strip

**Date:** 2026-06-01
**Status:** Approved design, pending implementation plan
**Author:** ansh.aneja

> Name `ClaudeStrip` is a placeholder and trivially renameable.

## Summary

A menubar-agent macOS app that displays live Claude Code usage in the **always-visible Touch Bar Control Strip**. It reuses the analytics engine from [Claude-Guardian](https://github.com/anshaneja5/Claude-Guardian) (`ClaudeAnalytics.swift`) verbatim as its data layer and puts a compact, tap-to-cycle usage readout on the right-hand Control Strip so usage is glanceable from any app.

## Goals

- Show Claude Code usage in the Touch Bar Control Strip, visible regardless of the frontmost app.
- Cycle through four metrics on tap: today's cost, 5h/7d rate-limit %, tokens today, live/active session cost.
- Zero changes to the user's Claude Code configuration (no hooks).
- Ship like Guardian: `.app` bundle, Homebrew cask, GitHub release CI, README, uninstaller.

## Non-Goals

- No permission gating, mascots, overlays, or anything else Guardian does — usage display only.
- No Claude Code hook installation. Active session is inferred from file modification times.
- No App Store distribution (Control Strip relies on private APIs — Homebrew only).
- No historical dashboard UI in v1 (the data layer supports it; out of scope for the strip).

## Key Decisions (locked during brainstorming)

| Decision | Choice |
|---|---|
| Placement | Always-visible **Control Strip** item (private DFR APIs) |
| Metrics shown | Today's cost, 5h/7d rate-limit %, tokens today, live/active session cost |
| Tap behavior | **Cycle** through the metrics, one at a time |
| Data source | **Hook-free** — `FileWatcher` on `~/.claude`; active session = newest-modified `.jsonl` |
| Polish level | **Shippable** like Guardian (bundle + Homebrew + CI + README) |

## Architecture

```
~/.claude/**  ──watch──▶  ClaudeAnalyticsStore  ──@Published──▶  AppDelegate
   (jsonl)                  (sync/parse)                            │
                                                                    ▼
                                              ControlStripController.render(metric)
                                                                    │  tap
                                                                    ▼
                                                          cycle metric index
```

The app runs as an `LSUIElement` agent (no Dock icon). On launch it starts the analytics store watching `~/.claude`, registers a persistent Control Strip item, and re-renders that item on every debounced sync. A minimal menubar item mirrors the current value and provides Quit.

## Components

Each unit has one purpose, a clear interface, and is independently understandable.

### `ClaudeAnalytics.swift` — data layer (copied from Guardian, unchanged)
- **Does:** Parses `~/.claude/projects/**/*.jsonl` `assistant` entries for token usage; computes cost via per-model pricing (Opus/Sonnet/Haiku) with fallback to logged `costUSD`; aggregates per-session and per-day; reads `*-usage-limits` files for 5h/7d percentages and reset times; watches `~/.claude` with a debounced POSIX `FileWatcher`.
- **Interface:** `ClaudeAnalyticsStore.shared` (`@MainActor ObservableObject`) exposing `@Published sessions`, `dailyStats`, `usageLimits`, plus `startWatching()` / `syncNow()` / `todayStats`.
- **Depends on:** Foundation, Cocoa, `~/.claude` on disk.
- **Note:** This file is already free of Guardian/UI dependencies; it is dropped in as-is.

### `ActiveSession.swift` — live-session detection (new, small)
- **Does:** Finds the newest-*modified* `.jsonl` under `~/.claude/projects` and maps it to its parsed session, yielding the "live/active session cost." (Guardian's parser sorts by *start* time; "active" requires *modification* time, hence this helper.)
- **Interface:** `ActiveSession.current(in sessions: [AnalyticsSessionRecord]) -> AnalyticsSessionRecord?` (or equivalent that resolves the newest-modified file's `sessionId` to a record).
- **Depends on:** `FileManager` (mod dates), the parsed session list from the store.

### `Metric.swift` — metric model + rendering (new, pure, unit-tested)
- **Does:** Enum of the four metrics; pure function rendering each to a compact Control-Strip string with a leading glyph.
- **Interface:** `enum Metric { case cost, limits, tokens, liveSession }` with `func render(from store: ClaudeAnalyticsStore, active: AnalyticsSessionRecord?) -> String` and `var next: Metric`.
- **Depends on:** Only the in-memory store snapshot (no I/O) → fully testable.
- **Rendered formats:**
  - `cost` → `$4.21`
  - `limits` → `⚡ 5h 62% 7d 18%`
  - `tokens` → `1.2M tok`
  - `liveSession` → `▶ $0.84`

### `ControlStripController.swift` — Touch Bar glue (new)
- **Does:** Builds an `NSCustomTouchBarItem` with a button view; registers it into the Control Strip via private DFR APIs; exposes `updateLabel(_:)`; routes taps to cycle the metric index.
- **Interface:** `init(onTap: () -> Void)`, `register()`, `updateLabel(_ text: String)`.
- **Depends on:** AppKit, private DFR symbols (via bridging header), Touch Bar hardware.

### `DFR-Bridging-Header.h` — private API declarations (new)
- **Does:** Declares `+[NSTouchBarItem addSystemTrayItem:]`, `DFRElementSetControlStripPresenceForIdentifier(NSString*, BOOL)`, and `DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL)`.
- **Build:** `swiftc … -import-objc-header DFR-Bridging-Header.h -F /System/Library/PrivateFrameworks -framework DFRFoundation`.

### `main.swift` — app entry + wiring (new)
- **Does:** `AppDelegate` starts `ClaudeAnalyticsStore.shared.startWatching()`, Combine-subscribes to its `@Published` properties → recomputes the current metric string → `ControlStripController.updateLabel`. Holds the current metric index (advanced on tap). Sets up a minimal `NSStatusItem` menubar fallback (mirrors current value; Quit). Configures `LSUIElement` behavior.
- **Depends on:** all units above, Combine.

## Data Flow & Refresh

1. `startWatching()` performs an initial `syncNow()` and starts `AnalyticsFileWatcher` on `~/.claude`.
2. Claude Code writes to a `.jsonl` → watcher fires (debounced ~1.5s) → `syncNow()` reparses → `@Published` properties update.
3. `AppDelegate`'s Combine sink recomputes the *currently selected* metric and calls `updateLabel`.
4. **Tap** only advances the metric index and re-renders from already-synced in-memory data — no reparse.

## Error / Edge Handling

- **No Touch Bar hardware / DFR registration fails:** detect the failure; fall back to displaying the value in the menubar item only. Never crash.
- **`~/.claude` missing or empty:** strip shows `—`.
- **No `*-usage-limits` file yet:** limits metric shows `⚡ 5h —`.
- **No active session detectable:** live-session metric shows `▶ —`.
- Underlying parsing already fails safe (`try?` throughout the Guardian code).

## Testing Strategy

- **TDD for pure logic (primary risk):**
  - `Metric.render` for each metric, including the empty/missing-data fallbacks (`—`).
  - `ActiveSession.current` — fixture `.claude` dir with multiple sessions; assert the newest-modified file's session wins.
- **Manual / integration:** DFR Control-Strip registration, persistence across app focus changes, and tap-to-cycle — not unit-testable (private APIs + hardware); verified by running the app and observing the strip.

## Packaging (shippable like Guardian)

- `build-app.sh` — compiles sources with the bridging header and DFRFoundation link into a `.app` bundle.
- `Info.plist` — `LSUIElement = true`, bundle metadata.
- LaunchAgent — start on login.
- `homebrew/claudestrip.rb` — Homebrew cask.
- `.github/workflows/release.yml` — build + GitHub release on tag push.
- `README.md` and `uninstall.sh` — mirroring Guardian's structure for familiarity.

## Risks & Tradeoffs

- **Private/undocumented APIs:** The always-visible Control Strip item uses the same private API category as Pock. Consequence: not App Store eligible; a future macOS could break registration. Accepted given the Control-Strip + Homebrew choices. Mitigated by the menubar fallback.
- **Inferred active session:** Newest-modified `.jsonl` is a heuristic, not authoritative; can briefly mis-attribute across concurrent sessions. Accepted in exchange for a zero-config, hook-free install.
- **Refresh latency:** ~1.5s debounce after Claude writes. Acceptable for a glanceable display.
