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
        let cycleItem = NSMenuItem(title: "Cycle metric", action: #selector(cycle), keyEquivalent: "")
        cycleItem.target = self
        menu.addItem(cycleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeStrip",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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

// Top-level main.swift executes on the main thread, so it is safe to assume
// MainActor isolation to construct the @MainActor delegate. `delegate` is a
// top-level global so it outlives `app.run()` (NSApplication.delegate is weak).
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
