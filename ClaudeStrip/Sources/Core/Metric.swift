import Foundation

/// The four usage metrics the Touch Bar item can display, in tap-cycle order.
public enum Metric: CaseIterable {
    case cost, limits, tokens, liveSession

    /// Renders this metric to a compact Control-Strip string from a snapshot.
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
            guard let c = s.liveSessionCost else { return "▶ —" }
            return String(format: "▶ $%.2f", c)
        }
    }

    /// The next metric in declaration order, wrapping around.
    public var next: Metric {
        let all = Metric.allCases
        let i = all.firstIndex(of: self)!
        return all[(i + 1) % all.count]
    }

    /// Everything at once for the wide Touch Bar strip:
    /// "$5.20 today  ·  41.7M tok  ·  ⚡ 5h 8% 7d 3%  ·  ▶ $0.84"
    /// Limits and live session are omitted when there is no data for them
    /// (no confusing dashes on the strip; the dashboard still shows them).
    public static func summary(from s: UsageSnapshot) -> String {
        var parts = [
            Metric.cost.render(from: s) + " today",
            Metric.tokens.render(from: s),
        ]
        if s.fiveHourPct != nil || s.sevenDayPct != nil {
            parts.append(Metric.limits.render(from: s))
        }
        if s.liveSessionCost != nil {
            parts.append(Metric.liveSession.render(from: s))
        }
        return parts.joined(separator: "  ·  ")
    }

    /// Compact human-readable token count: 1_200_000 -> "1.2M", 1_500 -> "1.5K".
    public static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
