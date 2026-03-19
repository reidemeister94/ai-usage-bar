import Combine
import SwiftUI

@MainActor
@Observable
final class AppState {
    var usageData: UsageData?
    var lastError: UsageError?
    var isRefreshing = false

    /// Settings — persisted via UserDefaults
    var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "refreshInterval")
            restartPolling()
        }
    }

    var showRemaining: Bool {
        didSet { UserDefaults.standard.set(showRemaining, forKey: "showRemaining") }
    }

    var preferredSource: PreferredSource {
        didSet { UserDefaults.standard.set(preferredSource.rawValue, forKey: "preferredSource") }
    }

    var onUsageUpdate: (() -> Void)?

    private var refreshTimer: Timer?
    private let usageRouter = UsageServiceRouter()
    private var consecutiveRateLimits = 0

    init() {
        let savedInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        refreshInterval = RefreshInterval(rawValue: savedInterval) ?? .fiveMinutes
        showRemaining = UserDefaults.standard.object(forKey: "showRemaining") as? Bool ?? true
        let savedSource = UserDefaults.standard.string(forKey: "preferredSource") ?? "Auto"
        preferredSource = PreferredSource(rawValue: savedSource) ?? .auto
    }

    func startPolling() {
        Task { await refresh() }
        restartPolling()
    }

    private func restartPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: effectiveInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    /// Backs off when rate-limited
    private var effectiveInterval: TimeInterval {
        if consecutiveRateLimits > 0 {
            let backoff = refreshInterval.seconds * pow(2.0, Double(min(consecutiveRateLimits, 4)))
            return min(backoff, 3600) // cap at 1 hour
        }
        return refreshInterval.seconds
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let data = try await usageRouter.fetchUsage(preferred: preferredSource)
            usageData = data
            lastError = nil
            if consecutiveRateLimits > 0 {
                consecutiveRateLimits = 0
                restartPolling()
            }
        } catch let error as UsageError {
            if case .rateLimited = error {
                consecutiveRateLimits += 1
                restartPolling()
            }
            self.lastError = error
        } catch {
            lastError = .networkError(error.localizedDescription)
        }

        onUsageUpdate?()
    }
}
