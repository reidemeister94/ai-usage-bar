import Foundation

struct UsageWindow: Sendable, Equatable {
    let percentUsed: Double       // 0.0 to 1.0
    let resetDate: Date?
    let isAvailable: Bool

    var percentRemaining: Double { 1.0 - percentUsed }

    var timeUntilReset: TimeInterval? {
        guard let resetDate else { return nil }
        let interval = resetDate.timeIntervalSinceNow
        return interval > 0 ? interval : nil
    }

    static let unavailable = UsageWindow(percentUsed: 0, resetDate: nil, isAvailable: false)
}

struct ExtraUsage: Sendable, Equatable {
    let spentCents: Int
    let limitCents: Int
    var spentDollars: Double { Double(spentCents) / 100.0 }
    var limitDollars: Double { Double(limitCents) / 100.0 }
}

struct UsageData: Sendable, Equatable {
    let session: UsageWindow
    let weekly: UsageWindow
    let opusWeekly: UsageWindow?
    let sonnetWeekly: UsageWindow?
    let extraUsage: ExtraUsage?
    let planInfo: PlanInfo?
    let fetchedAt: Date
    let source: DataSource

    enum DataSource: String, Sendable {
        case oauth, cli, web
    }
}
