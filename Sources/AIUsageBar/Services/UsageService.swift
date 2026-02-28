import Foundation

protocol UsageService: Sendable {
    func fetchUsage() async throws -> UsageData
    func isAvailable() async -> Bool
}
