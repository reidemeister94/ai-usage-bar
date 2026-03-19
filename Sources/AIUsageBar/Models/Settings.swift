import Foundation

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800

    var id: Int {
        rawValue
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    var label: String {
        switch self {
        case .fiveMinutes: "5 minutes"
        case .tenMinutes: "10 minutes"
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        }
    }
}

enum CookieSource: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case chrome = "Chrome"
    case safari = "Safari"

    var id: String {
        rawValue
    }
}

enum PreferredSource: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case oauth = "OAuth"
    case cli = "CLI"
    case web = "Web"

    var id: String {
        rawValue
    }
}

enum UsageError: Error {
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
    case rateLimited(retryAfter: TimeInterval?)
    case parseError(String)
    case networkError(String)

    var localizedDescription: String {
        switch self {
        case .noServiceAvailable: "No authentication method available"
        case .unauthorized: "Unauthorized — session may have expired"
        case let .forbidden(msg): "Access denied: \(msg)"
        case let .serverError(code): "Server error (\(code))"
        case .invalidResponse: "Invalid response from API"
        case let .keychainReadFailed(status): "Keychain read failed (status: \(status))"
        case .invalidCredentialFormat: "Invalid credential format"
        case let .missingScope(scope): "Missing OAuth scope: \(scope)"
        case .tokenRefreshFailed: "Token refresh failed"
        case .noCookieFound: "No session cookie found in browsers"
        case .cliTimeout: "Claude CLI timed out"
        case .cliNotFound: "Claude CLI not found"
        case .rateLimited: "Rate limited — backing off automatically"
        case let .parseError(msg): "Parse error: \(msg)"
        case let .networkError(msg): "Network error: \(msg)"
        }
    }
}
