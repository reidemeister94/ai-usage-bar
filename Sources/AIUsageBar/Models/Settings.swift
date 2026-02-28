import Foundation

enum RefreshInterval: Int, Sendable, CaseIterable, Identifiable {
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .oneMinute: "1 minute"
        case .twoMinutes: "2 minutes"
        case .fiveMinutes: "5 minutes"
        case .fifteenMinutes: "15 minutes"
        }
    }
}

enum CookieSource: String, Sendable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case chrome = "Chrome"
    case safari = "Safari"

    var id: String { rawValue }
}

enum PreferredSource: String, Sendable, CaseIterable, Identifiable {
    case auto = "Auto"
    case oauth = "OAuth"
    case cli = "CLI"
    case web = "Web"

    var id: String { rawValue }
}

enum UsageError: Error, Sendable {
    case noServiceAvailable
    case unauthorized
    case forbidden(String)
    case serverError(Int)
    case invalidResponse
    case keychainReadFailed(OSStatus)
    case invalidCredentialFormat
    case missingScope(String)
    case tokenRefreshFailed
    case noCookieFound
    case cliTimeout
    case cliNotFound
    case parseError(String)
    case networkError(String)

    var localizedDescription: String {
        switch self {
        case .noServiceAvailable: "No authentication method available"
        case .unauthorized: "Unauthorized — session may have expired"
        case .forbidden(let msg): "Access denied: \(msg)"
        case .serverError(let code): "Server error (\(code))"
        case .invalidResponse: "Invalid response from API"
        case .keychainReadFailed(let status): "Keychain read failed (status: \(status))"
        case .invalidCredentialFormat: "Invalid credential format"
        case .missingScope(let scope): "Missing OAuth scope: \(scope)"
        case .tokenRefreshFailed: "Token refresh failed"
        case .noCookieFound: "No session cookie found in browsers"
        case .cliTimeout: "Claude CLI timed out"
        case .cliNotFound: "Claude CLI not found"
        case .parseError(let msg): "Parse error: \(msg)"
        case .networkError(let msg): "Network error: \(msg)"
        }
    }
}
