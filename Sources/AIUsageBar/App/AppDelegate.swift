import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 24)

        if let button = statusItem.button {
            button.image = MenuBarIcon.render(session: 0, weekly: 0, dimmed: true)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: UsagePanelView(state: appState)
        )

        appState.onUsageUpdate = { [weak self] in
            self?.updateIcon()
        }

        appState.startPolling()
    }

    private func updateIcon() {
        guard let data = appState.usageData else {
            statusItem.button?.image = MenuBarIcon.render(session: 0, weekly: 0, dimmed: appState.lastError != nil)
            return
        }

        let session = appState.showRemaining ? data.session.percentRemaining : data.session.percentUsed
        let weekly = appState.showRemaining ? data.weekly.percentRemaining : data.weekly.percentUsed

        statusItem.button?.image = MenuBarIcon.render(
            session: session,
            weekly: weekly,
            dimmed: false
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
