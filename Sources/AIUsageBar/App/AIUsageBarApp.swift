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

        // Resolve the real executable path via _NSGetExecutablePath
        var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        var size = UInt32(MAXPATHLEN)
        guard _NSGetExecutablePath(&pathBuf, &size) == 0 else { return }
        guard let resolved = realpath(&pathBuf, nil) else { return }
        let execPath = String(cString: resolved)
        free(resolved)

        // Use posix_spawn (works before NSApplication is initialized,
        // unlike Process/NSTask which requires the run-loop).
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        // POSIX_SPAWN_SETSID (0x0400) creates a new session — clean
        // detach from the controlling terminal.
        let setsidFlag: Int16 = 0x0400
        posix_spawnattr_setflags(&attr, setsidFlag)

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addopen(
            &fileActions, STDIN_FILENO, "/dev/null", O_RDONLY, 0
        )
        posix_spawn_file_actions_addopen(
            &fileActions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0
        )
        posix_spawn_file_actions_addopen(
            &fileActions, STDERR_FILENO, "/dev/null", O_WRONLY, 0
        )

        let cPath = strdup(execPath)!
        let cFlag = strdup("--detached")!
        var argv: [UnsafeMutablePointer<CChar>?] = [cPath, cFlag, nil]

        var pid: pid_t = 0
        let rc = posix_spawn(
            &pid, execPath, &fileActions, &attr, &argv, environ
        )

        posix_spawn_file_actions_destroy(&fileActions)
        posix_spawnattr_destroy(&attr)
        free(cPath)
        free(cFlag)

        if rc == 0 { _exit(0) }
        // posix_spawn failed — continue in foreground
    }
}
