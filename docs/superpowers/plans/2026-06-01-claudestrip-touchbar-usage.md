# ClaudeStrip Touch Bar Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a menubar-agent macOS app that shows live Claude Code usage (today's cost, 5h/7d rate limits, tokens, live-session cost) in the always-visible Touch Bar Control Strip, cycling metrics on tap.

**Architecture:** Reuse Claude-Guardian's `ClaudeAnalytics.swift` verbatim as the data layer (parses `~/.claude` jsonl, computes cost, watches files). Pure-logic units (`UsageSnapshot`, `Metric`, `ActiveSession`) live in a Foundation-only `ClaudeStripCore` SPM library and are unit-tested with `swift test`. The AppKit layer (`ControlStripController`, `main.swift`) registers a Control Strip item via private DFR APIs and is verified manually. The shipped `.app` is built with `swiftc` compiling Core + App sources together against `DFRFoundation`.

**Tech Stack:** Swift 5.9, AppKit, Combine, Swift Package Manager (tests only), private `DFRFoundation.framework` + `+[NSTouchBarItem addSystemTrayItem:]`, `swiftc` direct compilation for the app bundle.

---

## File Structure

```
touchbar cc usage/
├── Package.swift                                   # SPM: ClaudeStripCore lib + tests ONLY
├── ClaudeStrip/
│   ├── Sources/
│   │   ├── Core/                                   # Foundation-only, public, unit-tested
│   │   │   ├── UsageSnapshot.swift                 # plain value type fed to the UI
│   │   │   ├── Metric.swift                        # enum + pure render(from:) + cycling
│   │   │   └── ActiveSession.swift                 # newest-modified jsonl -> sessionId
│   │   └── App/                                    # AppKit; built by build-app.sh, not SPM
│   │       ├── ClaudeAnalytics.swift               # VENDORED from Guardian, unchanged
│   │       ├── ControlStripController.swift        # DFR Control Strip glue
│   │       └── main.swift                          # AppDelegate wiring
│   ├── App/
│   │   ├── DFR-Bridging-Header.h                   # private API decls
│   │   └── Info.plist                              # LSUIElement agent
├── Tests/
│   └── ClaudeStripCoreTests/
│       ├── MetricTests.swift
│       └── ActiveSessionTests.swift
├── build-app.sh                                    # swiftc -> ClaudeStrip.app
├── post-install.sh                                 # LaunchAgent install
├── uninstall.sh
├── homebrew/claudestrip.rb
├── .github/workflows/release.yml
└── README.md
```

**Why Core types are `public`:** the test target imports `ClaudeStripCore` as a separate module, so the types and members it touches must be `public`. When `build-app.sh` compiles everything into one module, `public` is still valid.

---

### Task 1: Scaffold package + UsageSnapshot + first Metric test (cost)

**Files:**
- Create: `Package.swift`
- Create: `ClaudeStrip/Sources/Core/UsageSnapshot.swift`
- Create: `ClaudeStrip/Sources/Core/Metric.swift`
- Test: `Tests/ClaudeStripCoreTests/MetricTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeStrip",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ClaudeStripCore", path: "ClaudeStrip/Sources/Core"),
        .testTarget(
            name: "ClaudeStripCoreTests",
            dependencies: ["ClaudeStripCore"],
            path: "Tests/ClaudeStripCoreTests"
        ),
    ]
)
```

- [ ] **Step 2: Create `ClaudeStrip/Sources/Core/UsageSnapshot.swift`**

```swift
import Foundation

/// Immutable snapshot of the numbers the Touch Bar can display.
/// Built by the app from ClaudeAnalyticsStore; consumed by Metric.render.
public struct UsageSnapshot: Equatable {
    public var todayCost: Double
    public var todayTokens: Int
    public var fiveHourPct: Double?
    public var sevenDayPct: Double?
    public var liveSessionCost: Double?

    public init(todayCost: Double, todayTokens: Int,
                fiveHourPct: Double?, sevenDayPct: Double?,
                liveSessionCost: Double?) {
        self.todayCost = todayCost
        self.todayTokens = todayTokens
        self.fiveHourPct = fiveHourPct
        self.sevenDayPct = sevenDayPct
        self.liveSessionCost = liveSessionCost
    }

    public static let empty = UsageSnapshot(
        todayCost: 0, todayTokens: 0,
        fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil
    )
}
```

- [ ] **Step 3: Write the failing test `Tests/ClaudeStripCoreTests/MetricTests.swift`**

```swift
import XCTest
@testable import ClaudeStripCore

final class MetricTests: XCTestCase {
    func test_cost_formatsTwoDecimals() {
        let snap = UsageSnapshot(todayCost: 4.21, todayTokens: 0,
                                 fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)
        XCTAssertEqual(Metric.cost.render(from: snap), "$4.21")
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `swift test --filter MetricTests`
Expected: FAIL — `cannot find 'Metric' in scope` (Metric.swift not created yet).

- [ ] **Step 5: Create minimal `ClaudeStrip/Sources/Core/Metric.swift`**

```swift
import Foundation

public enum Metric: CaseIterable {
    case cost, limits, tokens, liveSession

    public func render(from s: UsageSnapshot) -> String {
        switch self {
        case .cost:
            return String(format: "$%.2f", s.todayCost)
        default:
            return ""
        }
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter MetricTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Package.swift ClaudeStrip/Sources/Core/UsageSnapshot.swift ClaudeStrip/Sources/Core/Metric.swift Tests/ClaudeStripCoreTests/MetricTests.swift
git commit -m "feat: scaffold ClaudeStripCore with UsageSnapshot and Metric.cost"
```

---

### Task 2: Metric.limits rendering (present + missing data)

**Files:**
- Modify: `ClaudeStrip/Sources/Core/Metric.swift`
- Test: `Tests/ClaudeStripCoreTests/MetricTests.swift`

- [ ] **Step 1: Add failing tests to `MetricTests.swift`**

```swift
    func test_limits_bothPresent_roundsToInt() {
        let snap = UsageSnapshot(todayCost: 0, todayTokens: 0,
                                 fiveHourPct: 62.4, sevenDayPct: 18.0, liveSessionCost: nil)
        XCTAssertEqual(Metric.limits.render(from: snap), "⚡ 5h 62% 7d 18%")
    }

    func test_limits_missing_showsDash() {
        let snap = UsageSnapshot(todayCost: 0, todayTokens: 0,
                                 fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)
        XCTAssertEqual(Metric.limits.render(from: snap), "⚡ 5h — 7d —")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MetricTests`
Expected: FAIL — `limits` returns `""` (the `default` branch), so equality fails.

- [ ] **Step 3: Implement the `.limits` case in `Metric.render`**

Replace the `default:` branch with explicit cases. The enum body becomes:

```swift
    public func render(from s: UsageSnapshot) -> String {
        switch self {
        case .cost:
            return String(format: "$%.2f", s.todayCost)
        case .limits:
            let five = s.fiveHourPct.map { "\(Int($0.rounded()))%" } ?? "—"
            let seven = s.sevenDayPct.map { "\(Int($0.rounded()))%" } ?? "—"
            return "⚡ 5h \(five) 7d \(seven)"
        case .tokens, .liveSession:
            return ""
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter MetricTests`
Expected: PASS (all three Metric tests).

- [ ] **Step 5: Commit**

```bash
git add ClaudeStrip/Sources/Core/Metric.swift Tests/ClaudeStripCoreTests/MetricTests.swift
git commit -m "feat: render Metric.limits with int rounding and dash fallback"
```

---

### Task 3: Metric.tokens rendering with K/M formatting

**Files:**
- Modify: `ClaudeStrip/Sources/Core/Metric.swift`
- Test: `Tests/ClaudeStripCoreTests/MetricTests.swift`

- [ ] **Step 1: Add failing tests to `MetricTests.swift`**

```swift
    func test_tokens_millions() {
        let snap = UsageSnapshot(todayCost: 0, todayTokens: 1_200_000,
                                 fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)
        XCTAssertEqual(Metric.tokens.render(from: snap), "1.2M tok")
    }

    func test_tokens_thousands() {
        let snap = UsageSnapshot(todayCost: 0, todayTokens: 1_500,
                                 fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)
        XCTAssertEqual(Metric.tokens.render(from: snap), "1.5K tok")
    }

    func test_tokens_small() {
        let snap = UsageSnapshot(todayCost: 0, todayTokens: 500,
                                 fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)
        XCTAssertEqual(Metric.tokens.render(from: snap), "500 tok")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MetricTests`
Expected: FAIL — `.tokens` currently returns `""`.

- [ ] **Step 3: Implement `.tokens` and the `formatTokens` helper**

Change the `case .tokens, .liveSession:` branch to handle tokens, and add a static helper. The enum becomes:

```swift
    public func render(from s: UsageSnapshot) -> String {
        switch self {
        case .cost:
            return String(format: "$%.2f", s.todayCost)
        case .limits:
            let five = s.fiveHourPct.map { "\(Int($0.rounded()))%" } ?? "—"
            let seven = s.sevenDayPct.map { "\(Int($0.rounded()))%" } ?? "—"
            return "⚡ 5h \(five) 7d \(seven)"
        case .tokens:
            return "\(Metric.formatTokens(s.todayTokens)) tok"
        case .liveSession:
            return ""
        }
    }

    public static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter MetricTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeStrip/Sources/Core/Metric.swift Tests/ClaudeStripCoreTests/MetricTests.swift
git commit -m "feat: render Metric.tokens with K/M formatting"
```

---

### Task 4: Metric.liveSession rendering + tap cycling

**Files:**
- Modify: `ClaudeStrip/Sources/Core/Metric.swift`
- Test: `Tests/ClaudeStripCoreTests/MetricTests.swift`

- [ ] **Step 1: Add failing tests to `MetricTests.swift`**

```swift
    func test_liveSession_present() {
        let snap = UsageSnapshot(todayCost: 0, todayTokens: 0,
                                 fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: 0.84)
        XCTAssertEqual(Metric.liveSession.render(from: snap), "▶ $0.84")
    }

    func test_liveSession_missing_showsDash() {
        let snap = UsageSnapshot.empty
        XCTAssertEqual(Metric.liveSession.render(from: snap), "▶ —")
    }

    func test_next_cyclesInOrderAndWraps() {
        XCTAssertEqual(Metric.cost.next, .limits)
        XCTAssertEqual(Metric.limits.next, .tokens)
        XCTAssertEqual(Metric.tokens.next, .liveSession)
        XCTAssertEqual(Metric.liveSession.next, .cost)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MetricTests`
Expected: FAIL — `.liveSession` returns `""` and `next` does not exist.

- [ ] **Step 3: Implement `.liveSession` case and the `next` property**

Replace the `case .liveSession:` branch and add `next` to the enum:

```swift
        case .liveSession:
            guard let c = s.liveSessionCost else { return "▶ —" }
            return String(format: "▶ $%.2f", c)
```

Add this property inside the enum (after `render`):

```swift
    public var next: Metric {
        let all = Metric.allCases
        let i = all.firstIndex(of: self)!
        return all[(i + 1) % all.count]
    }
```

(`allCases` order is declaration order: `cost, limits, tokens, liveSession`.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter MetricTests`
Expected: PASS (all Metric tests).

- [ ] **Step 5: Commit**

```bash
git add ClaudeStrip/Sources/Core/Metric.swift Tests/ClaudeStripCoreTests/MetricTests.swift
git commit -m "feat: render Metric.liveSession and add tap-cycling order"
```

---

### Task 5: ActiveSession — newest-modified jsonl detection

**Files:**
- Create: `ClaudeStrip/Sources/Core/ActiveSession.swift`
- Test: `Tests/ClaudeStripCoreTests/ActiveSessionTests.swift`

- [ ] **Step 1: Write the failing test `Tests/ClaudeStripCoreTests/ActiveSessionTests.swift`**

```swift
import XCTest
@testable import ClaudeStripCore

final class ActiveSessionTests: XCTestCase {

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudestrip-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeJSONL(_ name: String, in dir: URL, modifiedAt date: Date) {
        let url = dir.appendingPathComponent(name)
        try? "{}".data(using: .utf8)!.write(to: url)
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func test_returnsSessionIdOfNewestModifiedFile() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        writeJSONL("older-session.jsonl", in: dir, modifiedAt: Date(timeIntervalSince1970: 1000))
        writeJSONL("newer-session.jsonl", in: dir, modifiedAt: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(ActiveSession.newestModifiedSessionId(projectsRoot: dir), "newer-session")
    }

    func test_missingDirectory_returnsNil() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        XCTAssertNil(ActiveSession.newestModifiedSessionId(projectsRoot: missing))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter ActiveSessionTests`
Expected: FAIL — `cannot find 'ActiveSession' in scope`.

- [ ] **Step 3: Create `ClaudeStrip/Sources/Core/ActiveSession.swift`**

```swift
import Foundation

/// Determines the "active" Claude Code session without hooks:
/// the session whose .jsonl was modified most recently.
public enum ActiveSession {

    public static var defaultProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    /// Returns the session id (the .jsonl filename without extension) of the
    /// most-recently-modified session file under `projectsRoot`, or nil.
    public static func newestModifiedSessionId(projectsRoot: URL) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var newestURL: URL?
        var newestDate = Date.distantPast
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if date > newestDate {
                newestDate = date
                newestURL = url
            }
        }
        return newestURL?.deletingPathExtension().lastPathComponent
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter ActiveSessionTests`
Expected: PASS (both tests).

- [ ] **Step 5: Run the whole suite**

Run: `swift test`
Expected: PASS — all Metric + ActiveSession tests green.

- [ ] **Step 6: Commit**

```bash
git add ClaudeStrip/Sources/Core/ActiveSession.swift Tests/ClaudeStripCoreTests/ActiveSessionTests.swift
git commit -m "feat: detect active session via newest-modified jsonl"
```

---

### Task 6: Vendor ClaudeAnalytics.swift from Claude-Guardian

**Files:**
- Create: `ClaudeStrip/Sources/App/ClaudeAnalytics.swift` (downloaded, unchanged)

- [ ] **Step 1: Download the analytics engine verbatim**

```bash
mkdir -p "ClaudeStrip/Sources/App"
curl -fsSL \
  https://raw.githubusercontent.com/anshaneja5/Claude-Guardian/main/app/ClaudeGuardian/Sources/ClaudeAnalytics.swift \
  -o "ClaudeStrip/Sources/App/ClaudeAnalytics.swift"
```

- [ ] **Step 2: Verify it downloaded and exposes the expected symbols**

Run: `grep -E "class ClaudeAnalyticsStore|func startWatching|var todayStats|struct AnalyticsSessionRecord|struct AnalyticsDailyStats|var totalTokens" "ClaudeStrip/Sources/App/ClaudeAnalytics.swift"`
Expected: matches for `ClaudeAnalyticsStore`, `startWatching`, `todayStats`, `AnalyticsSessionRecord`, `AnalyticsDailyStats`, and `totalTokens`. These are the symbols Task 8 depends on:
- `ClaudeAnalyticsStore.shared` with `@Published sessions: [AnalyticsSessionRecord]`, `usageLimits: AnalyticsUsageLimitsRecord?`, `dailyStats`, `startWatching()`, `todayStats`
- `AnalyticsSessionRecord.sessionId: String`, `.costUSD: Double`
- `AnalyticsDailyStats.totalCostUSD: Double`, `.totalTokens: Int`
- `AnalyticsUsageLimitsRecord.fiveHourPercent: Double`, `.sevenDayPercent: Double`

- [ ] **Step 3: Commit**

```bash
git add ClaudeStrip/Sources/App/ClaudeAnalytics.swift
git commit -m "chore: vendor ClaudeAnalytics.swift from Claude-Guardian (unchanged)"
```

---

### Task 7: DFR bridging header + ControlStripController

No unit test — this layer calls private APIs and needs Touch Bar hardware. It is compile-checked here and behavior-verified in Task 9.

**Files:**
- Create: `ClaudeStrip/App/DFR-Bridging-Header.h`
- Create: `ClaudeStrip/Sources/App/ControlStripController.swift`

- [ ] **Step 1: Create `ClaudeStrip/App/DFR-Bridging-Header.h`**

```objc
#import <Cocoa/Cocoa.h>

// Private AppKit method that pins a Touch Bar item into the system tray /
// Control Strip so it is visible regardless of the frontmost app.
@interface NSTouchBarItem (PrivateControlStrip)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
@end

// Private DFRFoundation entry points for Control Strip presence.
extern void DFRElementSetControlStripPresenceForIdentifier(NSString *identifier, BOOL present);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL show);
```

- [ ] **Step 2: Create `ClaudeStrip/Sources/App/ControlStripController.swift`**

```swift
import AppKit

/// Owns a single NSCustomTouchBarItem pinned into the Control Strip via private
/// DFR APIs. Renders a string and reports taps. If registration fails (e.g. no
/// Touch Bar hardware) the app still functions via the menubar fallback.
final class ControlStripController {

    static let identifier = NSTouchBarItem.Identifier("app.claudestrip.usage")

    private let onTap: () -> Void
    private let button = NSButton(title: "—", target: nil, action: nil)
    private var item: NSCustomTouchBarItem?

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    func register() {
        DFRSystemModalShowsCloseBoxWhenFrontMost(true)

        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(handleTap)
        button.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)

        let newItem = NSCustomTouchBarItem(identifier: ControlStripController.identifier)
        newItem.view = button
        self.item = newItem

        NSTouchBarItem.addSystemTrayItem(newItem)
        DFRElementSetControlStripPresenceForIdentifier(
            ControlStripController.identifier.rawValue, true
        )
    }

    func updateLabel(_ text: String) {
        button.title = text
    }

    @objc private func handleTap() {
        onTap()
    }
}
```

- [ ] **Step 3: Compile-check this file in isolation against the private framework**

Run:
```bash
swiftc -typecheck \
  ClaudeStrip/Sources/App/ControlStripController.swift \
  -import-objc-header ClaudeStrip/App/DFR-Bridging-Header.h \
  -F /System/Library/PrivateFrameworks -framework DFRFoundation \
  -target arm64-apple-macosx13.0
```
Expected: no output, exit code 0 (type-checks; the private symbols resolve via the bridging header). If you see "cannot find 'addSystemTrayItem'", the bridging header path is wrong.

- [ ] **Step 4: Commit**

```bash
git add ClaudeStrip/App/DFR-Bridging-Header.h ClaudeStrip/Sources/App/ControlStripController.swift
git commit -m "feat: add DFR bridging header and Control Strip controller"
```

---

### Task 8: AppDelegate wiring (main.swift)

Wires the store to the strip: builds a `UsageSnapshot` on every sync, renders the current metric, and cycles on tap. Verified by building/running in Task 9.

**Files:**
- Create: `ClaudeStrip/Sources/App/main.swift`

- [ ] **Step 1: Create `ClaudeStrip/Sources/App/main.swift`**

```swift
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var cancellables = Set<AnyCancellable>()
    private var strip: ControlStripController!
    private var statusItem: NSStatusItem!
    private var metric: Metric = .cost
    private var snapshot: UsageSnapshot = .empty

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menubar fallback: always shows the current value and provides Quit.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "…"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Cycle metric", action: #selector(cycle), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeStrip",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items[0].target = self
        statusItem.menu = menu

        // Touch Bar Control Strip item.
        strip = ControlStripController(onTap: { [weak self] in self?.cycle() })
        strip.register()

        // Observe the analytics store and rebuild the snapshot on each sync.
        let store = ClaudeAnalyticsStore.shared
        store.$sessions
            .combineLatest(store.$dailyStats, store.$usageLimits)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in self?.rebuildSnapshot() }
            .store(in: &cancellables)

        store.startWatching()   // performs an initial syncNow() internally
    }

    private func rebuildSnapshot() {
        let store = ClaudeAnalyticsStore.shared
        let today = store.todayStats

        let liveId = ActiveSession.newestModifiedSessionId(
            projectsRoot: ActiveSession.defaultProjectsRoot
        )
        let liveCost = liveId.flatMap { id in
            store.sessions.first { $0.sessionId == id }?.costUSD
        }

        snapshot = UsageSnapshot(
            todayCost: today?.totalCostUSD ?? 0,
            todayTokens: today?.totalTokens ?? 0,
            fiveHourPct: store.usageLimits?.fiveHourPercent,
            sevenDayPct: store.usageLimits?.sevenDayPercent,
            liveSessionCost: liveCost
        )
        render()
    }

    @objc private func cycle() {
        metric = metric.next
        render()
    }

    private func render() {
        let text = metric.render(from: snapshot)
        strip.updateLabel(text)
        statusItem.button?.title = text
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
```

> Note on `store.usageLimits?.fiveHourPercent`: when no usage-limits file exists, `usageLimits` is `nil`, so `fiveHourPct`/`sevenDayPct` become `nil` and `Metric.limits` renders `⚡ 5h — 7d —` as designed.

- [ ] **Step 2: Commit** (build happens in Task 9)

```bash
git add ClaudeStrip/Sources/App/main.swift
git commit -m "feat: wire AppDelegate — store -> snapshot -> Control Strip + menubar"
```

---

### Task 9: build-app.sh + Info.plist — build and run

**Files:**
- Create: `ClaudeStrip/App/Info.plist`
- Create: `build-app.sh`

- [ ] **Step 1: Create `ClaudeStrip/App/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ClaudeStrip</string>
    <key>CFBundleDisplayName</key>
    <string>ClaudeStrip</string>
    <key>CFBundleIdentifier</key>
    <string>app.claudestrip</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeStrip</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Create `build-app.sh`**

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="ClaudeStrip"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SRC="$SCRIPT_DIR/ClaudeStrip/Sources"
BRIDGE="$SCRIPT_DIR/ClaudeStrip/App/DFR-Bridging-Header.h"

echo "Building $APP_NAME.app ..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

COMMON_FLAGS=(
  -import-objc-header "$BRIDGE"
  -F /System/Library/PrivateFrameworks -framework DFRFoundation
  -framework Cocoa
  -O
)

build_arch () {
  local arch="$1"
  swiftc -o "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-${arch}" \
    "$SRC"/Core/*.swift \
    "$SRC"/App/*.swift \
    "${COMMON_FLAGS[@]}" \
    -target "${arch}-apple-macosx13.0"
}

echo "[1/3] Compiling (arm64 + x86_64)..."
build_arch arm64
build_arch x86_64
lipo -create \
  "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-arm64" \
  "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-x86_64" \
  -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
rm "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-arm64" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-x86_64"

echo "[2/3] Copying Info.plist..."
cp "$SCRIPT_DIR/ClaudeStrip/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "[3/3] Done -> $APP_BUNDLE"
```

- [ ] **Step 3: Make it executable and build**

Run:
```bash
chmod +x build-app.sh && ./build-app.sh
```
Expected: ends with `Done -> .../build/ClaudeStrip.app` and no compiler errors. If `swiftc` reports a missing symbol from `ClaudeAnalytics.swift`, re-check Task 6 Step 2.

- [ ] **Step 4: Run the app and verify the Control Strip (manual)**

Run: `open build/ClaudeStrip.app`
Expected, observe ALL of:
1. A menubar item appears showing a value like `$0.00` or your real today's cost (no Dock icon).
2. The Touch Bar Control Strip (right side) shows the same value.
3. Tapping the Control Strip item cycles: cost → `⚡ 5h … 7d …` → `… tok` → `▶ …` → back.
4. Clicking the menubar item → "Cycle metric" advances it too; "Quit ClaudeStrip" quits.

If the Control Strip item does not appear but the menubar value does, the DFR registration failed — the app is still usable; capture any console output via `Console.app` filtered to `ClaudeStrip` for debugging before proceeding.

- [ ] **Step 5: Commit**

```bash
git add ClaudeStrip/App/Info.plist build-app.sh
git commit -m "feat: build script + Info.plist; produces runnable ClaudeStrip.app"
```

---

### Task 10: Start-on-login (LaunchAgent) + install/uninstall scripts

**Files:**
- Create: `post-install.sh`
- Create: `uninstall.sh`

- [ ] **Step 1: Create `post-install.sh`**

```bash
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
```

- [ ] **Step 2: Create `uninstall.sh`**

```bash
#!/bin/bash
PLIST="$HOME/Library/LaunchAgents/app.claudestrip.plist"

pkill -f "ClaudeStrip.app/Contents/MacOS/ClaudeStrip" 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -f /tmp/claudestrip.log /tmp/claudestrip.err
echo "ClaudeStrip uninstalled (app bundle not removed; delete it from /Applications if desired)."
```

- [ ] **Step 3: Verify the scripts are syntactically valid**

Run: `bash -n post-install.sh && bash -n uninstall.sh && echo OK`
Expected: `OK` (no syntax errors). Do not execute them yet — they target `/Applications`; full install is exercised via Homebrew in Task 11 or manually after copying the app.

- [ ] **Step 4: Commit**

```bash
chmod +x post-install.sh uninstall.sh
git add post-install.sh uninstall.sh
git commit -m "feat: LaunchAgent install + uninstall scripts"
```

---

### Task 11: Packaging — Homebrew cask, release CI, README

**Files:**
- Create: `homebrew/claudestrip.rb`
- Create: `.github/workflows/release.yml`
- Create: `README.md`
- Modify: `build-app.sh` (append a zip step)

- [ ] **Step 1: Append a zip step to `build-app.sh`**

Add these lines at the end of `build-app.sh` (after the final `echo`):

```bash
echo "[zip] Creating ClaudeStrip.zip..."
( cd "$BUILD_DIR" && ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip" )
echo "Packaged -> $BUILD_DIR/$APP_NAME.zip"
```

- [ ] **Step 2: Re-run the build to confirm the zip is produced**

Run: `./build-app.sh && ls -1 build/ClaudeStrip.zip`
Expected: `build/ClaudeStrip.zip` listed.

- [ ] **Step 3: Create `.github/workflows/release.yml`**

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests
        run: swift test
      - name: Build app bundle
        run: ./build-app.sh
      - name: Create GitHub release
        uses: softprops/action-gh-release@v2
        with:
          files: build/ClaudeStrip.zip
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 4: Create `homebrew/claudestrip.rb`**

Replace `YOUR_GH_USER` with the actual GitHub owner once the repo exists. `sha256 :no_check` is used until the first release zip is published; replace with the real checksum after the first release.

```ruby
cask "claudestrip" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/YOUR_GH_USER/ClaudeStrip/releases/download/v#{version}/ClaudeStrip.zip"
  name "ClaudeStrip"
  desc "Claude Code usage in the macOS Touch Bar Control Strip"
  homepage "https://github.com/YOUR_GH_USER/ClaudeStrip"

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
```

> The cask's `postflight` runs `post-install.sh` from inside the bundle's `Resources`. For that to work, add a copy step to `build-app.sh` if you want Homebrew-driven install: `cp post-install.sh uninstall.sh "$APP_BUNDLE/Contents/Resources/"` before the zip step. Add this line now (right after the Info.plist copy in `build-app.sh`):
> ```bash
> cp "$SCRIPT_DIR/post-install.sh" "$SCRIPT_DIR/uninstall.sh" "$APP_BUNDLE/Contents/Resources/"
> ```

- [ ] **Step 5: Create `README.md`**

```markdown
# ClaudeStrip

Claude Code usage, live in your MacBook Pro Touch Bar Control Strip.

Shows — and cycles on tap — four metrics drawn entirely from your local
`~/.claude` data:

- 💵 **Today's cost** (`$4.21`)
- ⚡ **Rate limits** (`⚡ 5h 62% 7d 18%`)
- 🔢 **Tokens today** (`1.2M tok`)
- ▶️ **Live session cost** (`▶ $0.84`)

100% local. No hooks, no config changes, nothing leaves your machine. The
analytics engine is reused from [Claude-Guardian](https://github.com/anshaneja5/Claude-Guardian).

## How it works

A menubar-agent app watches `~/.claude` and parses session `.jsonl` files for
token usage and cost (with per-model pricing), plus the rolling 5h/7d rate-limit
snapshots. It pins one item into the Touch Bar Control Strip (via private DFR
APIs, the same approach Pock uses) so the current metric is always visible.
Tap to cycle metrics. The "active" session is the most-recently-modified
session file. A menubar item mirrors the value and provides Quit.

## Install

### Homebrew

```bash
brew install --cask YOUR_GH_USER/tap/claudestrip
```

> Gatekeeper (unsigned app): if macOS blocks first launch, run
> `xattr -cr /Applications/ClaudeStrip.app` once, then reopen.

### From source

```bash
git clone https://github.com/YOUR_GH_USER/ClaudeStrip.git
cd ClaudeStrip
swift test          # run unit tests
./build-app.sh      # produces build/ClaudeStrip.app
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
```

- [ ] **Step 6: Re-run build to confirm Resources copy + zip still succeed**

Run: `./build-app.sh && ls build/ClaudeStrip.app/Contents/Resources/`
Expected: lists `post-install.sh` and `uninstall.sh`; `build/ClaudeStrip.zip` exists.

- [ ] **Step 7: Validate workflow + cask syntax**

Run:
```bash
ruby -c homebrew/claudestrip.rb
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('yaml ok')"
```
Expected: `Syntax OK` from ruby and `yaml ok` from python.

- [ ] **Step 8: Commit**

```bash
git add homebrew/claudestrip.rb .github/workflows/release.yml README.md build-app.sh
git commit -m "feat: packaging — Homebrew cask, release CI, README"
```

---

## Final verification (run after all tasks)

- [ ] `swift test` — all Core unit tests pass.
- [ ] `./build-app.sh` — builds `ClaudeStrip.app` and `ClaudeStrip.zip` with no errors.
- [ ] `open build/ClaudeStrip.app` — Control Strip shows the current metric; tap cycles all four; menubar mirrors the value and quits cleanly.
- [ ] No remaining `YOUR_GH_USER` placeholders once the GitHub repo owner is known (README + cask).

---

## Spec Coverage Map

| Spec requirement | Task(s) |
|---|---|
| Reuse `ClaudeAnalytics.swift` verbatim | Task 6 |
| Active session = newest-modified jsonl | Task 5, wired in Task 8 |
| `Metric` enum + compact renders + fallbacks | Tasks 1–4 |
| Control Strip via private DFR APIs | Task 7 |
| Tap cycles metrics | Task 4 (`next`) + Task 8 (`cycle`) |
| Debounced file-watch refresh | Task 6 (vendored watcher) + Task 8 (Combine sink) |
| Menubar fallback + Quit | Task 8 |
| No-data / no-limits / no-Touch-Bar handling | Tasks 2 & 4 (dashes), Task 8 note, Task 9 Step 4 |
| `LSUIElement` agent, start-on-login | Task 9 (plist) + Task 10 (LaunchAgent) |
| Shippable: build script, Homebrew, CI, README, uninstall | Tasks 9, 10, 11 |
| TDD for pure logic; manual for UI/DFR | Tasks 1–5 (TDD); Tasks 7 & 9 (manual) |
