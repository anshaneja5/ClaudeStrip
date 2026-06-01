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
