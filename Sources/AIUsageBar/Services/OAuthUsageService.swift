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
            return try await handleUnauthorized(token: token)
        case 429:
            return try await handleRateLimited(token: token, response: http)
        case 403:
            throw UsageError.forbidden("OAuth usage endpoint returned 403")
        default:
            throw UsageError.serverError(http.statusCode)
        }
    }

    private func handleUnauthorized(token: OAuthToken) async throws -> UsageData {
        KeychainReader.invalidateCache()
        guard let refreshToken = token.refreshToken else {
            throw UsageError.unauthorized
        }
        let newToken = try await TokenRefresher.refresh(using: refreshToken)
        KeychainReader.updateCache(newToken)
        KeychainReader.persistToFile(newToken)
        return try await fetchWithToken(newToken)
    }

    /// Rate-limited: refresh the token to get a fresh rate limit window
    private func handleRateLimited(
        token: OAuthToken,
        response: HTTPURLResponse
    ) async throws -> UsageData {
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            .flatMap { TimeInterval($0) }

        // Token refresh resets the per-token rate limit window
        guard let refreshToken = token.refreshToken else {
            throw UsageError.rateLimited(retryAfter: retryAfter)
        }

        do {
            let newToken = try await TokenRefresher.refresh(using: refreshToken)
            KeychainReader.invalidateCache()
            KeychainReader.updateCache(newToken)
            KeychainReader.persistToFile(newToken)
            return try await fetchWithToken(newToken)
        } catch {
            throw UsageError.rateLimited(retryAfter: retryAfter)
        }
    }

    private func fetchWithToken(_ token: OAuthToken) async throws -> UsageData {
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
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw UsageError.rateLimited(retryAfter: retryAfter)
        default:
            throw UsageError.unauthorized
        }
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
            coworkWeekly: parseWindowOptional(json["seven_day_cowork"]),
            oauthAppsWeekly: parseWindowOptional(json["seven_day_oauth_apps"]),
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
        let isEnabled = dict["is_enabled"] as? Bool ?? false
        guard isEnabled else { return nil }
        let monthlyLimit = dict["monthly_limit"] as? Int ?? 0
        let usedCredits = (dict["used_credits"] as? NSNumber)?.doubleValue ?? 0.0
        let utilization = (dict["utilization"] as? NSNumber)?.doubleValue
        return ExtraUsage(
            isEnabled: isEnabled,
            monthlyLimitCents: monthlyLimit,
            usedCreditsCents: usedCredits,
            utilization: utilization
        )
    }

    /// ISO8601 with fractional seconds and +00:00 timezone
    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
