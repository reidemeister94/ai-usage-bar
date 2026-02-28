import Foundation

final class UsageServiceRouter: Sendable {
    private let oauthService = OAuthUsageService()
    private let cliService = CLIUsageService()
    private let webService = WebUsageService()

    func fetchUsage(preferred: PreferredSource = .auto) async throws -> UsageData {
        switch preferred {
        case .oauth:
            return try await oauthService.fetchUsage()
        case .cli:
            return try await cliService.fetchUsage()
        case .web:
            return try await webService.fetchUsage()
        case .auto:
            return try await fetchWithCascade()
        }
    }

    private func fetchWithCascade() async throws -> UsageData {
        // OAuth first — most reliable for team orgs
        if await oauthService.isAvailable() {
            do {
                return try await oauthService.fetchUsage()
            } catch {
                // Fall through to next
            }
        }

        // CLI fallback
        if await cliService.isAvailable() {
            do {
                return try await cliService.fetchUsage()
            } catch {
                // Fall through to next
            }
        }

        // Web cookies as last resort
        if await webService.isAvailable() {
            return try await webService.fetchUsage()
        }

        throw UsageError.noServiceAvailable
    }
}
