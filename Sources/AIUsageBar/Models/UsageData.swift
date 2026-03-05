import Foundation

struct UsageWindow: Sendable, Equatable {
    let percentUsed: Double // 0.0 to 1.0
    let resetDate: Date?
    let isAvailable: Bool

    var percentRemaining: Double {
        1.0 - percentUsed
    }

    var timeUntilReset: TimeInterval? {
        guard let resetDate else { return nil }
        let interval = resetDate.timeIntervalSinceNow
        return interval > 0 ? interval : nil
    }

    static let unavailable = UsageWindow(percentUsed: 0, resetDate: nil, isAvailable: false)
}

struct ExtraUsage: Sendable, Equatable {
    let isEnabled: Bool
    let monthlyLimitCents: Int
    let usedCreditsCents: Double
    let utilization: Double?

    var spentDollars: Double {
        usedCreditsCents / 100.0
    }

    var limitDollars: Double {
        Double(monthlyLimitCents) / 100.0
    }
}

struct UsageData: Sendable, Equatable {
    let session: UsageWindow
    let weekly: UsageWindow
    let opusWeekly: UsageWindow?
    let sonnetWeekly: UsageWindow?
    let coworkWeekly: UsageWindow?
    let oauthAppsWeekly: UsageWindow?
    let extraUsage: ExtraUsage?
    let planInfo: PlanInfo?
    let fetchedAt: Date
    let source: DataSource

    enum DataSource: String, Sendable {
        case oauth, cli, web
    }
}
