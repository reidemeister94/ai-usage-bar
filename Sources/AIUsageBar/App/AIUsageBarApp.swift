import Foundation
import SwiftUI

@main
struct AIUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        Self.detachFromTerminalIfNeeded()
    }

    var body: some Scene {
        // Menu bar only — no window, no dock icon
        Settings {
            EmptyView()
        }
    }

    /// When launched from a terminal, re-exec as a detached background
    /// process so the shell prompt returns immediately and closing the
    /// terminal does not kill the app.
    private static func detachFromTerminalIfNeeded() {
        let args = CommandLine.arguments
        // Already detached — just ignore SIGHUP and continue
        if args.contains("--detached") {
            signal(SIGHUP, SIG_IGN)
            return
        }
        // --foreground flag keeps the process in the terminal (for debugging)
        guard isatty(STDIN_FILENO) != 0,
              !args.contains("--foreground")
        else { return }

        // Re-launch ourselves detached from the terminal
        let task = Process()
        task.executableURL = URL(fileURLWithPath: args[0])
        task.arguments = ["--detached"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.environment = ProcessInfo.processInfo.environment
        do {
            try task.run()
        } catch {
            return // failed to detach — continue in foreground
        }
        _exit(0)
    }
}
