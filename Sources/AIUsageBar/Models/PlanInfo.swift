import Foundation

struct PlanInfo: Sendable, Equatable {
    let tier: PlanTier
    let orgName: String?
    let email: String?

    enum PlanTier: String, Sendable, CaseIterable {
        case free = "Free"
        case pro = "Pro"
        case max = "Max"
        case team = "Team"
        case enterprise = "Enterprise"
        case unknown = "Unknown"

        init(fromRateLimitTier tier: String?) {
            guard let tier = tier?.lowercased() else { self = .unknown; return }
            if tier.contains("enterprise") { self = .enterprise }
            else if tier.contains("team") { self = .team }
            else if tier.contains("max") { self = .max }
            else if tier.contains("pro") { self = .pro }
            else if tier.contains("free") { self = .free }
            else { self = .unknown }
        }
    }
}
