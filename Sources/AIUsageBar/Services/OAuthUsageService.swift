import Foundation

struct OAuthUsageService: UsageService {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func isAvailable() async -> Bool {
        (try? KeychainReader.readClaudeCredentials().hasProfileScope) ?? false
    }

    func fetchUsage() async throws -> UsageData {
        let token = try KeychainReader.readClaudeCredentials()

        guard token.hasProfileScope else {
            throw UsageError.missingScope("user:profile")
        }

        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return try parseResponse(data, token: token)
        case 401:
            // Try refreshing the token
            if let refreshToken = token.refreshToken {
                let newToken = try await TokenRefresher.refresh(using: refreshToken)
                return try await fetchWithToken(newToken)
            }
            throw UsageError.unauthorized
        case 403:
            throw UsageError.forbidden("OAuth usage endpoint returned 403")
        default:
            throw UsageError.serverError(http.statusCode)
        }
    }

    private func fetchWithToken(_ token: OAuthToken) async throws -> UsageData {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageError.unauthorized
        }
        return try parseResponse(data, token: token)
    }

    private func parseResponse(_ data: Data, token: OAuthToken) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.invalidResponse
        }

        let planInfo = PlanInfo(
            tier: PlanInfo.PlanTier(fromRateLimitTier: token.rateLimitTier),
            orgName: token.organizationName,
            email: token.email
        )

        return UsageData(
            session: parseWindow(json["five_hour"]),
            weekly: parseWindow(json["seven_day"]),
            opusWeekly: parseWindowOptional(json["seven_day_opus"]),
            sonnetWeekly: parseWindowOptional(json["seven_day_sonnet"]),
            extraUsage: parseExtraUsage(json["extra_usage"]),
            planInfo: planInfo,
            fetchedAt: Date(),
            source: .oauth
        )
    }

    private func parseWindow(_ raw: Any?) -> UsageWindow {
        guard let dict = raw as? [String: Any] else {
            return .unavailable
        }
        let utilization = (dict["utilization"] as? NSNumber)?.doubleValue ?? 0.0
        let resetStr = dict["resets_at"] as? String
        let resetDate = resetStr.flatMap { Self.parseISO8601($0) }
        return UsageWindow(
            percentUsed: min(1.0, utilization / 100.0),
            resetDate: resetDate,
            isAvailable: true
        )
    }

    private func parseWindowOptional(_ raw: Any?) -> UsageWindow? {
        guard raw != nil else { return nil }
        let window = parseWindow(raw)
        return window.isAvailable ? window : nil
    }

    private func parseExtraUsage(_ raw: Any?) -> ExtraUsage? {
        guard let dict = raw as? [String: Any] else { return nil }
        guard let spent = dict["spend_cents"] as? Int,
              let limit = dict["limit_cents"] as? Int else { return nil }
        return ExtraUsage(spentCents: spent, limitCents: limit)
    }

    // ISO8601 with fractional seconds and +00:00 timezone
    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
