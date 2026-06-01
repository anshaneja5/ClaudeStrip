import Foundation

// Lightweight test runner for ClaudeStripCore. Compiled with `swiftc` (see
// run-tests.sh) so it works without SwiftPM. Exits non-zero on any failure.

var failures = 0
var passes = 0

func check(_ got: String, _ want: String, _ name: String) {
    if got == want { passes += 1; print("ok   \(name)") }
    else { failures += 1; print("FAIL \(name): got \"\(got)\" want \"\(want)\"") }
}

func checkOpt(_ got: String?, _ want: String?, _ name: String) {
    if got == want { passes += 1; print("ok   \(name)") }
    else { failures += 1; print("FAIL \(name): got \(String(describing: got)) want \(String(describing: want))") }
}

// MARK: - Metric.render

check(Metric.cost.render(from: UsageSnapshot(todayCost: 4.21, todayTokens: 0,
      fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)), "$4.21", "cost_formatsTwoDecimals")

check(Metric.limits.render(from: UsageSnapshot(todayCost: 0, todayTokens: 0,
      fiveHourPct: 62.4, sevenDayPct: 18.0, liveSessionCost: nil)), "⚡ 5h 62% 7d 18%", "limits_bothPresent_roundsToInt")

check(Metric.limits.render(from: .empty), "⚡ 5h — 7d —", "limits_missing_showsDash")

check(Metric.tokens.render(from: UsageSnapshot(todayCost: 0, todayTokens: 1_200_000,
      fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)), "1.2M tok", "tokens_millions")

check(Metric.tokens.render(from: UsageSnapshot(todayCost: 0, todayTokens: 1_500,
      fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)), "1.5K tok", "tokens_thousands")

check(Metric.tokens.render(from: UsageSnapshot(todayCost: 0, todayTokens: 500,
      fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: nil)), "500 tok", "tokens_small")

check(Metric.liveSession.render(from: UsageSnapshot(todayCost: 0, todayTokens: 0,
      fiveHourPct: nil, sevenDayPct: nil, liveSessionCost: 0.84)), "▶ $0.84", "liveSession_present")

check(Metric.liveSession.render(from: .empty), "▶ —", "liveSession_missing_showsDash")

// MARK: - Metric cycling

check("\(Metric.cost.next)", "limits", "next_cost")
check("\(Metric.limits.next)", "tokens", "next_limits")
check("\(Metric.tokens.next)", "liveSession", "next_tokens")
check("\(Metric.liveSession.next)", "cost", "next_wraps")

// MARK: - ActiveSession

let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("claudestrip-tests-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

func writeJSONL(_ name: String, modifiedAt date: Date) {
    let url = dir.appendingPathComponent(name)
    try? "{}".data(using: .utf8)!.write(to: url)
    try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}

writeJSONL("older-session.jsonl", modifiedAt: Date(timeIntervalSince1970: 1000))
writeJSONL("newer-session.jsonl", modifiedAt: Date(timeIntervalSince1970: 2000))
checkOpt(ActiveSession.newestModifiedSessionId(projectsRoot: dir), "newer-session",
         "activeSession_returnsNewestModified")

let missing = FileManager.default.temporaryDirectory
    .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
checkOpt(ActiveSession.newestModifiedSessionId(projectsRoot: missing), nil,
         "activeSession_missingDirectory_returnsNil")

try? FileManager.default.removeItem(at: dir)

// MARK: - Summary

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
