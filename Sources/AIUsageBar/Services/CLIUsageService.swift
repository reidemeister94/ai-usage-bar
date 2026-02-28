import Foundation

struct CLIUsageService: UsageService {
    func isAvailable() async -> Bool {
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/claude").path,
        ]
        return candidates.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func fetchUsage() async throws -> UsageData {
        // Run: claude usage --output json
        // If that fails, try the interactive /usage approach
        let output: String
        do {
            output = try await PTYSession.runClaude(
                arguments: ["usage", "--output", "json"],
                input: "",
                timeout: 15
            )
        } catch {
            // Fallback: try interactive mode
            output = try await PTYSession.runClaude(
                arguments: [],
                input: "/usage\nexit\n",
                timeout: 15
            )
        }

        return try parseOutput(output)
    }

    private func parseOutput(_ raw: String) throws -> UsageData {
        // Strip ANSI escape codes
        let clean = raw.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )

        // Try JSON parsing first
        if let jsonData = clean.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            return try parseJSON(json)
        }

        // Fall back to text parsing
        return try parseText(clean)
    }

    private func parseJSON(_ json: [String: Any]) throws -> UsageData {
        func windowFromJSON(_ key: String) -> UsageWindow {
            guard let dict = json[key] as? [String: Any] else { return .unavailable }
            let percent = (dict["percent_used"] as? NSNumber)?.doubleValue
                ?? (dict["utilization"] as? NSNumber)?.doubleValue
                ?? 0
            let resetStr = dict["resets_at"] as? String
            let resetDate = resetStr.flatMap { ISO8601DateFormatter().date(from: $0) }
            return UsageWindow(percentUsed: min(1, percent / 100.0), resetDate: resetDate, isAvailable: true)
        }

        return UsageData(
            session: windowFromJSON("session"),
            weekly: windowFromJSON("weekly"),
            opusWeekly: nil,
            sonnetWeekly: nil,
            extraUsage: nil,
            planInfo: nil,
            fetchedAt: Date(),
            source: .cli
        )
    }

    private func parseText(_ text: String) throws -> UsageData {
        let session = parseSection(text, keywords: ["session", "5-hour", "5 hour", "5h"])
        let weekly = parseSection(text, keywords: ["week", "7-day", "7 day", "7d"])

        guard session.isAvailable || weekly.isAvailable else {
            throw UsageError.parseError("Could not parse CLI output")
        }

        return UsageData(
            session: session,
            weekly: weekly,
            opusWeekly: nil,
            sonnetWeekly: nil,
            extraUsage: nil,
            planInfo: nil,
            fetchedAt: Date(),
            source: .cli
        )
    }

    private func parseSection(_ text: String, keywords: [String]) -> UsageWindow {
        let lines = text.components(separatedBy: .newlines)
        var foundSection = false
        var percentUsed: Double?
        var resetDate: Date?

        for line in lines {
            let lower = line.lowercased()

            if keywords.contains(where: { lower.contains($0) }) {
                foundSection = true
            }

            guard foundSection else { continue }

            // Look for percentage patterns
            if percentUsed == nil {
                if let match = lower.range(of: "(\\d+\\.?\\d*)\\s*%", options: .regularExpression) {
                    let numStr = String(lower[match]).replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                    if let num = Double(numStr) {
                        percentUsed = lower.contains("remaining") || lower.contains("left")
                            ? (100 - num) / 100.0
                            : num / 100.0
                    }
                }
            }

            // Look for reset time patterns like "Xh Ym" or "X hours"
            if resetDate == nil, lower.contains("reset") {
                var totalSeconds: TimeInterval = 0
                if let hMatch = lower.range(of: "(\\d+)\\s*h", options: .regularExpression) {
                    let h = Double(String(lower[hMatch]).filter(\.isNumber)) ?? 0
                    totalSeconds += h * 3600
                }
                if let mMatch = lower.range(of: "(\\d+)\\s*m", options: .regularExpression) {
                    let m = Double(String(lower[mMatch]).filter(\.isNumber)) ?? 0
                    totalSeconds += m * 60
                }
                if totalSeconds > 0 {
                    resetDate = Date().addingTimeInterval(totalSeconds)
                }
            }

            // Stop at next section
            if foundSection, percentUsed != nil, line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
        }

        guard let used = percentUsed else {
            return .unavailable
        }

        return UsageWindow(percentUsed: min(1.0, used), resetDate: resetDate, isAvailable: true)
    }
}
