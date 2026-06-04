import AppKit

/// Drives the Touch Bar in two parts:
///  - a small Claude-logo tray item pinned into the Control Strip (always there)
///  - a wide system-modal bar showing ALL metrics at once, taking real width
/// Tapping the wide strip refreshes the data; the logo tray item shows/hides
/// the strip. Uses the same private APIs as MTMR/Pock. If anything fails, the
/// menubar dashboard still works.
final class ControlStripController: NSObject, NSTouchBarDelegate {

    static let trayIdentifier = NSTouchBarItem.Identifier("app.claudestrip.tray")
    static let statsIdentifier = NSTouchBarItem.Identifier("app.claudestrip.stats")

    private let onTap: () -> Void
    private let statsButton = NSButton(title: "—", target: nil, action: nil)
    private var modalBar: NSTouchBar!
    private var isPresented = false

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    func register() {
        NSLog("[ClaudeStrip] register() begin")
        DFRSystemModalShowsCloseBoxWhenFrontMost(true)

        // Small always-visible tray item: just the Claude logo, toggles the bar.
        let trayButton = NSButton(image: ClaudeLogo.nsImage(size: 22),
                                  target: self, action: #selector(toggleBar))
        trayButton.bezelStyle = .rounded
        let tray = NSCustomTouchBarItem(identifier: ControlStripController.trayIdentifier)
        tray.view = trayButton
        NSTouchBarItem.addSystemTrayItem(tray)
        DFRElementSetControlStripPresenceForIdentifier(
            ControlStripController.trayIdentifier.rawValue, true
        )

        // Wide stats strip: logo + all metrics in one legible line.
        // Tapping it refreshes the data (it does NOT hide the strip).
        statsButton.bezelStyle = .rounded
        statsButton.target = self
        statsButton.action = #selector(statsTapped)
        statsButton.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        statsButton.image = ClaudeLogo.nsImage(size: 18)
        statsButton.imagePosition = .imageLeading
        statsButton.imageHugsTitle = true

        modalBar = NSTouchBar()
        modalBar.delegate = self
        modalBar.defaultItemIdentifiers = [ControlStripController.statsIdentifier]

        presentBar()
        NSLog("[ClaudeStrip] register() done — tray + wide bar presented")
    }

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == ControlStripController.statsIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: ControlStripController.statsIdentifier)
        item.view = statsButton
        return item
    }

    func updateLabel(_ text: String) {
        statsButton.title = text
        statsButton.sizeToFit()
    }

    @objc private func toggleBar() {
        isPresented ? dismissBar() : presentBar()
    }

    @objc private func statsTapped() {
        onTap()
    }

    private func presentBar() {
        NSTouchBar.presentSystemModalTouchBar(
            modalBar, systemTrayItemIdentifier: ControlStripController.trayIdentifier
        )
        isPresented = true
    }

    private func dismissBar() {
        NSTouchBar.dismissSystemModalTouchBar(modalBar)
        isPresented = false
    }
}
