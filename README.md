<p align="center">
  <img src="assets/logo.png" width="110" alt="ClaudeStrip logo">
</p>

<h1 align="center">ClaudeStrip</h1>

<p align="center">
  <em>Live Claude Code usage on your MacBook Touch Bar — cost, tokens, and rate limits, always one glance away.</em>
</p>

<p align="center">
  <a href="https://github.com/anshaneja5/ClaudeStrip/releases"><img src="https://img.shields.io/github/v/release/anshaneja5/ClaudeStrip?color=D97757&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black" alt="macOS 13+">
  <img src="https://img.shields.io/badge/data-100%25%20local-D97757" alt="100% local">
</p>

---

While you code, your Touch Bar shows everything that matters:

```
┌──────────────────────────────────────────────────────────────────────┐
│  ✳  $5.20 today  ·  41.7M tok  ·  ⚡ 5h 8% 7d 3%  ·  ▶ $0.84    🔆 🔊 │
└──────────────────────────────────────────────────────────────────────┘
```

And the menubar dashboard gives you the full picture on **any** Mac — Touch Bar or not:

| | Today | All-time |
|---|---|---|
| **Cost** | $5.20 | $312.40 |
| **Tokens** | 41.7M | 1.2B |
| **Messages** | 452 | 38,201 |
| **Sessions** | 2 | 743 |

…plus color-coded **5h / 7d rate-limit bars** with reset countdowns, and a **7-day cost chart**.

<!-- Drop your screenshots into assets/ and uncomment:
<p align="center">
  <img src="assets/dashboard.png" width="380" alt="Menubar dashboard">
  <img src="assets/touchbar.jpg" width="600" alt="Touch Bar strip">
</p>
-->

Everything is parsed from your local `~/.claude` data. **No hooks, no config changes, nothing ever leaves your machine.**

## Install

```bash
brew install --cask anshaneja5/tap/claudestrip
```

That's it — the app starts immediately and on every login.

> **Gatekeeper note (unsigned app):** if macOS blocks the first launch, run
> `xattr -cr /Applications/ClaudeStrip.app` once, then reopen.

<details>
<summary><strong>From source</strong></summary>

```bash
git clone https://github.com/anshaneja5/ClaudeStrip.git
cd ClaudeStrip
./run-tests.sh     # unit tests (plain swiftc — no SwiftPM needed)
./build-app.sh     # produces build/ClaudeStrip.app
open build/ClaudeStrip.app
```

Requires Swift 5.9+ (Xcode or Command Line Tools).
</details>

## Using it

| Where | Action | Result |
|---|---|---|
| **Touch Bar** — wide strip | Tap | Refresh the numbers now |
| **Touch Bar** — ✳ logo (Control Strip) | Tap | Show / hide the wide strip |
| **Menubar** — ✳ + today's cost | Click | Open the dashboard |
| **Dashboard** — ↻ button | Click | Force a re-sync |
| **Dashboard** — Quit button | Click | Quit ClaudeStrip |

Data also refreshes automatically ~1.5s after Claude Code writes to `~/.claude`.

## How it works

A tiny menubar agent watches `~/.claude` and parses the session `.jsonl` files
for token usage, computing cost with per-model pricing (Opus / Sonnet / Haiku),
plus Claude Code's rolling 5-hour / 7-day rate-limit snapshots. The wide Touch
Bar strip is presented through the same private macOS APIs that
[Pock](https://pock.app) and MTMR pioneered. The analytics engine is reused
from [Claude-Guardian](https://github.com/anshaneja5/Claude-Guardian).

## FAQ

**My rate limits show nothing / showed `—`.**
Your `~/.claude` has no rate-limit snapshot files yet — Claude Code writes them
during active use. The segment appears in the strip automatically once data
exists. Check with: `find ~/.claude/projects -name "*-usage-limits" | head`

**My Touch Bar is completely black (but touch still works).**
That's a known **macOS 26 (Tahoe) bug**, not ClaudeStrip — no app can draw to
the bar in that state. Try ` → Restart`, or quit `TouchBarServer` in Activity
Monitor and restart. The menubar dashboard keeps working regardless.

**I don't have a Touch Bar.**
You still get the menubar dashboard — cost, tokens, limits, and the chart all
live there. Only the strip itself needs Touch Bar hardware (2016–2020 MacBook
Pros).

**Is my data sent anywhere?**
No. ClaudeStrip reads local files and renders them. There is no network code
in the app.

**Why isn't this on the App Store?**
The always-visible Touch Bar integration requires private Apple APIs, which the
App Store doesn't allow. Hence Homebrew.

## Development

- **Core logic** (`UsageSnapshot`, `Metric`, `ActiveSession`) is Foundation-only
  and unit-tested via `./run-tests.sh` — a plain `swiftc` test runner, so it
  works even where SwiftPM is broken.
- **The app** is built by `./build-app.sh` with `swiftc` directly, linking the
  private `DFRFoundation` framework via `ClaudeStrip/App/DFR-Bridging-Header.h`.
- **Releasing:** bump the version in `ClaudeStrip/App/Info.plist` +
  `homebrew/claudestrip.rb`, run `./build-app.sh`, update the cask `sha256`
  from the new zip, tag `vX.Y.Z`, upload the zip to the GitHub release, and
  copy the cask into [`anshaneja5/homebrew-tap`](https://github.com/anshaneja5/homebrew-tap).

## Credits

Built in free time as an excuse to finally give the Touch Bar a purpose.
Analytics engine from [Claude-Guardian](https://github.com/anshaneja5/Claude-Guardian) ·
Touch Bar technique from the [Pock](https://pock.app) / MTMR lineage.
