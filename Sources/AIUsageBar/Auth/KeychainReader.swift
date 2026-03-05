import Foundation
import Security

struct OAuthToken: Sendable {
    let accessToken: String
    let refreshToken: String?
    let scopes: Set<String>
    let organizationUUID: String?
    let organizationName: String?
    let accountUUID: String?
    let email: String?
    let rateLimitTier: String?

    var hasProfileScope: Bool {
        scopes.contains("user:profile")
    }
}

enum KeychainReader {
    private nonisolated(unsafe) static var cachedToken: OAuthToken?

    static func readClaudeCredentials() throws -> OAuthToken {
        if let cached = cachedToken {
            return cached
        }

        // Try credentials file first (no Keychain authorization prompt)
        if let token = try? readFromFile() {
            cachedToken = token
            return token
        }
        // Fallback to Keychain (may trigger macOS authorization prompt)
        if let token = try? readFromKeychain() {
            cachedToken = token
            return token
        }
        throw UsageError.keychainReadFailed(-1)
    }

    /// Update the cached token (e.g. after a successful token refresh).
    static func updateCache(_ token: OAuthToken) {
        cachedToken = token
    }

    static func invalidateCache() {
        cachedToken = nil
    }

    private static func readFromKeychain() throws -> OAuthToken {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw UsageError.keychainReadFailed(status)
        }

        return try parseCredentialData(data)
    }

    private static func readFromFile() throws -> OAuthToken {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent(".claude/.credentials.json")
        let data = try Data(contentsOf: path)
        return try parseCredentialData(data)
    }

    private static func parseCredentialData(_ data: Data) throws -> OAuthToken {
        let json = try JSONSerialization.jsonObject(with: data)

        guard let root = json as? [String: Any] else {
            throw UsageError.invalidCredentialFormat
        }

        // Claude Code stores credentials under "claudeAiOauth" key
        let dict: [String: Any]
        if let nested = root["claudeAiOauth"] as? [String: Any] {
            dict = nested
        } else if root["accessToken"] != nil || root["access_token"] != nil {
            dict = root
        } else {
            throw UsageError.invalidCredentialFormat
        }

        // Handle both camelCase (Keychain) and snake_case (file) formats
        guard let accessToken = (dict["accessToken"] as? String) ?? (dict["access_token"] as? String) else {
            throw UsageError.invalidCredentialFormat
        }

        // Scopes can be an array of strings or a space-separated string
        let scopes: Set<String> = if let arr = dict["scopes"] as? [String] {
            Set(arr)
        } else if let str = dict["scope"] as? String {
            Set(str.split(separator: " ").map(String.init))
        } else {
            []
        }

        let refreshToken = (dict["refreshToken"] as? String) ?? (dict["refresh_token"] as? String)
        let rateLimitTier = (dict["rateLimitTier"] as? String) ?? (dict["rate_limit_tier"] as? String)
        let subscriptionType = dict["subscriptionType"] as? String

        let org = dict["organization"] as? [String: Any]
        let account = dict["account"] as? [String: Any]

        // organizationUUID/Name may come from nested object or from
        // `claude auth status` enrichment later
        let orgUUID = org?["uuid"] as? String
            ?? dict["organizationUUID"] as? String
        let orgName = org?["name"] as? String
            ?? dict["organizationName"] as? String
        let acctUUID = account?["uuid"] as? String
            ?? dict["accountUUID"] as? String
        let email = account?["email_address"] as? String
            ?? dict["email"] as? String

        return OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            scopes: scopes,
            organizationUUID: orgUUID,
            organizationName: orgName,
            accountUUID: acctUUID,
            email: email,
            rateLimitTier: rateLimitTier ?? subscriptionType
        )
    }
}
