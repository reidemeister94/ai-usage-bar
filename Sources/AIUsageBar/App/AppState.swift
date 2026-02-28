import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    var usageData: UsageData?
    var lastError: UsageError?
    var isRefreshing: Bool = false

    // Settings — persisted via UserDefaults
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

    init() {
        let savedInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        self.refreshInterval = RefreshInterval(rawValue: savedInterval) ?? .twoMinutes
        self.showRemaining = UserDefaults.standard.object(forKey: "showRemaining") as? Bool ?? true
        let savedSource = UserDefaults.standard.string(forKey: "preferredSource") ?? "Auto"
        self.preferredSource = PreferredSource(rawValue: savedSource) ?? .auto
    }

    func startPolling() {
        Task { await refresh() }
        restartPolling()
    }

    private func restartPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: refreshInterval.seconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let data = try await usageRouter.fetchUsage(preferred: preferredSource)
            self.usageData = data
            self.lastError = nil
        } catch {
            self.lastError = error as? UsageError ?? .networkError(error.localizedDescription)
        }

        onUsageUpdate?()
    }
}
