import AppKit
import ServiceManagement

/// The ♪ icon in the menu bar, with "Launch at Login" and "Quit".
///
/// - `NSStatusItem` = an icon on the right side of the menu bar.
/// - `SMAppService.mainApp` = Apple's official API for adding this app to Login Items
///   (shown in System Settings → General → Login Items).
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")

    override init() {
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchMusic")
            image?.isTemplate = true  // template = macOS tints it to match the light/dark menu bar
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "NotchMusic", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NotchMusic", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Refresh the checkmark every time the menu opens, in case it was changed in System Settings.
    func menuWillOpen(_ menu: NSMenu) {
        updateLaunchAtLoginItem()
    }

    private func updateLaunchAtLoginItem() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginItem.title = "Launch at Login"
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.title = "Launch at Login (approve in System Settings)"
            launchAtLoginItem.state = .mixed
        default:
            launchAtLoginItem.title = "Launch at Login"
            launchAtLoginItem.state = .off
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            appLog.error("Launch at login change failed: \(String(describing: error), privacy: .public)")
            showError(error)
        }
        // macOS sometimes asks the user to confirm in System Settings first.
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        updateLaunchAtLoginItem()
    }

    private func showError(_ error: Error) {
        NSApp.activate()  // bring the alert to the front (we have no windows of our own)
        let alert = NSAlert()
        alert.messageText = "Couldn't change Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
