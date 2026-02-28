import Foundation

struct WebUsageService: UsageService {
    func isAvailable() async -> Bool {
        CookieExtractor.extractSessionKey() != nil
    }

    func fetchUsage() async throws -> UsageData {
        guard let sessionKey = CookieExtractor.extractSessionKey() else {
            throw UsageError.noCookieFound
        }

        // Step 1: Get organizations
        let orgId = try await fetchOrganizationId(sessionKey: sessionKey)

        // Step 2: Get account UUID (needed for team orgs)
        let accountUUID = try? await fetchAccountUUID(sessionKey: sessionKey)

        // Step 3: Fetch usage (with account_uuid for team org fix)
        let usage = try await fetchUsageData(
            sessionKey: sessionKey,
            orgId: orgId,
            accountUUID: accountUUID
        )

        return usage
    }

    private func fetchOrganizationId(sessionKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://claude.ai/api/organizations")!)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageError.unauthorized
        }

        guard let orgs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = orgs.first,
              let uuid = first["uuid"] as? String else {
            throw UsageError.invalidResponse
        }

        return uuid
    }

    private func fetchAccountUUID(sessionKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://claude.ai/api/account")!)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageError.unauthorized
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uuid = json["uuid"] as? String else {
            throw UsageError.invalidResponse
        }

        return uuid
    }

    private func fetchUsageData(sessionKey: String, orgId: String, accountUUID: String?) async throws -> UsageData {
        var urlString = "https://claude.ai/api/organizations/\(orgId)/usage"
        if let accountUUID {
            urlString += "?account_uuid=\(accountUUID)"
        }

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return try parseUsageResponse(data)
        case 403:
            throw UsageError.forbidden("Usage API returned 403 for org \(orgId)")
        default:
            throw UsageError.serverError(http.statusCode)
        }
    }

    private func parseUsageResponse(_ data: Data) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.invalidResponse
        }

        return UsageData(
            session: parseWindow(json["session"] ?? json["five_hour"]),
            weekly: parseWindow(json["weekly"] ?? json["seven_day"]),
            opusWeekly: parseWindowOptional(json["seven_day_opus"]),
            sonnetWeekly: parseWindowOptional(json["seven_day_sonnet"]),
            extraUsage: nil,
            planInfo: nil,
            fetchedAt: Date(),
            source: .web
        )
    }

    private func parseWindow(_ raw: Any?) -> UsageWindow {
        guard let dict = raw as? [String: Any] else { return .unavailable }

        // Handle different response formats
        let utilization: Double
        if let u = (dict["utilization"] as? NSNumber)?.doubleValue {
            utilization = u
        } else if let u = (dict["percent_used"] as? NSNumber)?.doubleValue {
            utilization = u
        } else {
            return .unavailable
        }

        let resetStr = dict["resets_at"] as? String ?? dict["reset_at"] as? String
        let resetDate = resetStr.flatMap { ISO8601DateFormatter().date(from: $0) }

        return UsageWindow(
            percentUsed: min(1.0, utilization / 100.0),
            resetDate: resetDate,
            isAvailable: true
        )
    }

    private func parseWindowOptional(_ raw: Any?) -> UsageWindow? {
        guard raw != nil else { return nil }
        let w = parseWindow(raw)
        return w.isAvailable ? w : nil
    }
}
