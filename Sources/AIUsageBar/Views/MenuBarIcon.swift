import AppKit

enum MenuBarIcon {
    private static let iconWidth: CGFloat = 18
    private static let iconHeight: CGFloat = 18

    static func render(session: Double, weekly: Double, dimmed: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: iconWidth, height: iconHeight), flipped: false) { rect in
            let fillAlpha: CGFloat = dimmed ? 0.3 : 1.0
            let outlineAlpha: CGFloat = dimmed ? 0.15 : 0.4

            let barWidth: CGFloat = 14
            let barX: CGFloat = (rect.width - barWidth) / 2

            // Outer rounded rect outline
            let outerRect = NSRect(x: barX, y: 2, width: barWidth, height: 14)
            let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 2.5, yRadius: 2.5)
            NSColor.black.withAlphaComponent(outlineAlpha).setStroke()
            outerPath.lineWidth = 1.0
            outerPath.stroke()

            let inset: CGFloat = 1.5
            let innerWidth = barWidth - inset * 2

            // Top bar — session (5h window)
            let sessionFill = max(0, min(1, session))
            let sessionRect = NSRect(
                x: barX + inset,
                y: 8,
                width: innerWidth * sessionFill,
                height: 6
            )
            NSColor.black.withAlphaComponent(fillAlpha).setFill()
            NSBezierPath(roundedRect: sessionRect, xRadius: 1, yRadius: 1).fill()

            // Bottom hairline — weekly (7d window)
            let weeklyFill = max(0, min(1, weekly))
            let weeklyRect = NSRect(
                x: barX + inset,
                y: 4,
                width: innerWidth * weeklyFill,
                height: 2
            )
            NSColor.black.withAlphaComponent(fillAlpha).setFill()
            NSBezierPath(roundedRect: weeklyRect, xRadius: 0.5, yRadius: 0.5).fill()

            return true
        }
        image.isTemplate = true
        return image
    }
}
