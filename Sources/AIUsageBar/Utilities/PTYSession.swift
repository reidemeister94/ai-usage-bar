import Foundation

enum PTYSession {
    static func runClaude(arguments: [String], input: String, timeout: TimeInterval = 15) async throws -> String {
        let claudePath = findClaudeBinary()
        guard let path = claudePath else {
            throw UsageError.cliNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.environment = ProcessInfo.processInfo.environment

                let outputPipe = Pipe()
                let inputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe
                process.standardInput = inputPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: UsageError.cliNotFound)
                    return
                }

                // Send input
                if let data = input.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(data)
                    inputPipe.fileHandleForWriting.closeFile()
                }

                // Read with timeout
                var output = ""
                let deadline = Date().addingTimeInterval(timeout)
                let handle = outputPipe.fileHandleForReading

                while Date() < deadline {
                    let available = handle.availableData
                    if available.isEmpty { break }
                    output += String(data: available, encoding: .utf8) ?? ""
                    if output.contains("resets") || output.contains("usage") || output.count > 2000 {
                        break
                    }
                }

                process.terminate()

                if output.isEmpty {
                    continuation.resume(throwing: UsageError.cliTimeout)
                } else {
                    continuation.resume(returning: output)
                }
            }
        }
    }

    private static func findClaudeBinary() -> String? {
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            ProcessInfo.processInfo.environment["HOME"].map { "\($0)/.local/bin/claude" },
            ProcessInfo.processInfo.environment["HOME"].map { "\($0)/.claude/local/claude" },
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
