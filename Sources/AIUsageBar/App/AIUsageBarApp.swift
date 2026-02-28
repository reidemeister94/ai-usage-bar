import SwiftUI

@main
struct AIUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // Menu bar only — no window, no dock icon
        Settings {
            EmptyView()
        }
    }
}
