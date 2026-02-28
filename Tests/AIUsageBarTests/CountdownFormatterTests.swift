import Testing
@testable import AIUsageBar

@Suite("CountdownFormatter")
struct CountdownFormatterTests {
    @Test("formats days and hours")
    func formatDaysAndHours() {
        #expect(CountdownFormatter.format(90000) == "1d 1h")
    }

    @Test("formats hours and minutes")
    func formatHoursAndMinutes() {
        #expect(CountdownFormatter.format(3660) == "1h 1m")
    }

    @Test("formats minutes only")
    func formatMinutesOnly() {
        #expect(CountdownFormatter.format(120) == "2m")
    }

    @Test("formats less than a minute")
    func formatLessThanMinute() {
        #expect(CountdownFormatter.format(30) == "<1m")
    }
}
