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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            GeometryReader { geo in
                let fillWidth = max(0, geo.size.width * window.percentUsed)
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.25))

                    // Fill
                    Capsule()
                        .fill(barColor.opacity(0.8))
                        .frame(width: fillWidth)

                    // Dot indicator at fill point
                    Circle()
                        .fill(barColor)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, fillWidth - 4))
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(Int(displayPercent * 100))% \(showRemaining ? "left" : "used")")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
                if let remaining = window.timeUntilReset {
                    Text("Resets in \(CountdownFormatter.format(remaining))")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
        }
    }
}
