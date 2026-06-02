import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var cancellables = Set<AnyCancellable>()
    private var strip: ControlStripController!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var metric: Metric = .cost
    private var snapshot: UsageSnapshot = .empty

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menubar item: Claude logo + current value; click opens the dashboard.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = ClaudeLogo.nsImage(size: 15)
            button.imagePosition = .imageLeading
            button.title = "…"
            button.target = self
            button.action = #selector(togglePopover)
        }

        // The big, beautiful dashboard popover.
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatsView())

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

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
