import SwiftUI

struct UsageRowView: View {
    let title: String
    let window: UsageWindow
    let showRemaining: Bool

    private var displayPercent: Double {
        showRemaining ? window.percentRemaining : window.percentUsed
    }

    private var barColor: Color {
        let used = window.percentUsed
        if used < 0.5 { return .green }
        if used < 0.75 { return .yellow }
        if used < 0.9 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(displayPercent * 100))% \(showRemaining ? "left" : "used")")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.85))
                        .frame(width: geo.size.width * window.percentUsed)
                }
            }
            .frame(height: 8)

            if let resetDate = window.resetDate, let remaining = window.timeUntilReset {
                HStack(spacing: 4) {
                    Text("Resets in \(CountdownFormatter.format(remaining))")
                    Text("(\(CountdownFormatter.absoluteTime(resetDate)))")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
    }
}
