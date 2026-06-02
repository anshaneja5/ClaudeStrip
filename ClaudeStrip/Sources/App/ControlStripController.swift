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
        NSLog("[ClaudeStrip] register() begin")
        DFRSystemModalShowsCloseBoxWhenFrontMost(true)

        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(handleTap)
        // Larger, bolder, monospaced digits so it's legible in the narrow strip.
        button.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        button.sizeToFit()

        let newItem = NSCustomTouchBarItem(identifier: ControlStripController.identifier)
        newItem.view = button
        self.item = newItem

        NSTouchBarItem.addSystemTrayItem(newItem)
        DFRElementSetControlStripPresenceForIdentifier(
            ControlStripController.identifier.rawValue, true
        )
        NSLog("[ClaudeStrip] register() done — item added to control strip")
    }

    func updateLabel(_ text: String) {
        button.title = text
        // Resize the item to fit the new text so longer metrics aren't clipped.
        button.sizeToFit()
    }

    @objc private func handleTap() {
        onTap()
    }
}
