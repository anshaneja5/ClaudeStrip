import SwiftUI
import Charts

/// The menubar dashboard shown in a popover. Binds live to ClaudeAnalyticsStore.
struct StatsView: View {
    @ObservedObject var store = ClaudeAnalyticsStore.shared

    private var last7: [AnalyticsDailyStats] { Array(store.dailyStats.suffix(7)) }

    private var allTimeCost: Double { store.sessions.reduce(0) { $0 + $1.costUSD } }
    private var allTimeTokens: Int { store.sessions.reduce(0) { $0 + $1.totalTokens } }
    private var allTimeMessages: Int { store.sessions.reduce(0) { $0 + $1.messageCount } }
    private var allTimeSessions: Int { store.sessions.count }

    private func grouped(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            todayCard
            limitsSection
            chartSection
            Divider()
            footer
        }
        .padding(18)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: ClaudeLogo.nsImage(size: 30))
            VStack(alignment: .leading, spacing: 1) {
                Text("ClaudeStrip").font(.headline)
                Text("Claude Code usage · 100% local")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if store.isSyncing {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.syncNow() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 28) {
                costColumn("TODAY", store.todayStats?.totalCostUSD ?? 0)
                costColumn("ALL TIME", allTimeCost)
                Spacer()
            }
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 7) {
                GridRow {
                    Text("")
                    Text("Today").font(.caption2).foregroundStyle(.secondary)
                    Text("All-time").font(.caption2).foregroundStyle(.secondary)
                }
                gridStat("Tokens",
                         Metric.formatTokens(store.todayStats?.totalTokens ?? 0),
                         Metric.formatTokens(allTimeTokens))
                gridStat("Messages",
                         grouped(store.todayStats?.messageCount ?? 0),
                         grouped(allTimeMessages))
                gridStat("Sessions",
                         grouped(store.todayStats?.sessionCount ?? 0),
                         grouped(allTimeSessions))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    private func costColumn(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(String(format: "$%.2f", value))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    @ViewBuilder
    private func gridStat(_ label: String, _ today: String, _ all: String) -> some View {
        GridRow {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(today).font(.callout.bold().monospacedDigit())
            Text(all).font(.callout.bold().monospacedDigit())
        }
    }

    private var limitsSection: some View {
        VStack(spacing: 12) {
            LimitBar(label: "5-hour limit",
                     pct: store.usageLimits?.fiveHourPercent,
                     resets: store.usageLimits?.fiveHourTimeRemaining)
            LimitBar(label: "7-day limit",
                     pct: store.usageLimits?.sevenDayPercent,
                     resets: store.usageLimits?.sevenDayTimeRemaining)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST 7 DAYS").font(.caption2.bold()).foregroundStyle(.secondary)
            if last7.isEmpty {
                Text("No data yet")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                Chart(last7) { day in
                    BarMark(
                        x: .value("Day", Self.weekday(day.date)),
                        y: .value("Cost", day.totalCostUSD)
                    )
                    .foregroundStyle(Color(nsColor: ClaudeLogo.coral))
                    .cornerRadius(3)
                }
                .frame(height: 90)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let sync = store.lastSyncDate {
                Text("updated \(Self.clock(sync))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
        }
    }

    private static func weekday(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d)
    }

    private static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: d)
    }
}

/// A labeled usage-limit progress bar, color-coded by how close to the cap.
private struct LimitBar: View {
    let label: String
    let pct: Double?
    let resets: String?

    private var fraction: CGFloat { CGFloat(min((pct ?? 0) / 100, 1)) }
    private var barColor: Color {
        let p = pct ?? 0
        if p >= 90 { return .red }
        if p >= 70 { return .orange }
        return Color(nsColor: ClaudeLogo.coral)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(pct != nil ? "\(Int(pct!.rounded()))%" : "—")
                    .font(.caption.monospacedDigit()).bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule().fill(barColor).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            if let resets {
                Text("resets in \(resets)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
