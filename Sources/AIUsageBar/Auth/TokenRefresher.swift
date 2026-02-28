import Foundation

enum TokenRefresher {
    // Claude Code's public OAuth client ID
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private static let tokenURL = URL(string: "https://console.anthropic.com/api/oauth/token")!

    static func refresh(using refreshToken: String) async throws -> OAuthToken {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageError.tokenRefreshFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let accessToken = json["access_token"] as? String else {
            throw UsageError.tokenRefreshFailed
        }

        let scopeString = json["scope"] as? String ?? ""
        let scopes = Set(scopeString.split(separator: " ").map(String.init))
        let org = json["organization"] as? [String: Any]
        let account = json["account"] as? [String: Any]

        return OAuthToken(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String ?? refreshToken,
            scopes: scopes,
            organizationUUID: org?["uuid"] as? String,
            organizationName: org?["name"] as? String,
            accountUUID: account?["uuid"] as? String,
            email: account?["email_address"] as? String,
            rateLimitTier: json["rate_limit_tier"] as? String
        )
    }
}
