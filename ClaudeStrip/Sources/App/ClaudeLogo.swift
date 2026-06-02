import AppKit

/// Draws a Claude-style coral sunburst mark, used on the Touch Bar item and in
/// the menubar dashboard header. Rendered in code so it stays crisp at any size.
enum ClaudeLogo {

    /// Claude's signature coral.
    static let coral = NSColor(srgbRed: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0, alpha: 1)

    static func nsImage(size: CGFloat, color: NSColor = coral) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        draw(in: NSRect(x: 0, y: 0, width: size, height: size), color: color)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Radiating rounded spokes — a clean sunburst "spark".
    static func draw(in rect: NSRect, color: NSColor) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let spokes = 12
        let inner = radius * 0.14
        let outer = radius * 0.96
        let lineWidth = radius * 0.16

        color.setStroke()
        for i in 0..<spokes {
            let angle = CGFloat(i) / CGFloat(spokes) * 2 * .pi
            let p1 = NSPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
            let p2 = NSPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
            let path = NSBezierPath()
            path.move(to: p1)
            path.line(to: p2)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
        }
    }
}
