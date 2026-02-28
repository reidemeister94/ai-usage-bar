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
                Text(
                    "\(Int(displayPercent * 100))% "
                        + "\(showRemaining ? "left" : "used")"
                )
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let fillWidth = max(
                    0,
                    geo.size.width * window.percentUsed
                )
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 6)

            if let remaining = window.timeUntilReset {
                Text(
                    "Resets in "
                        + CountdownFormatter.format(remaining)
                )
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
