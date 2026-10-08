import AppKit

/// App entry point. `@main` tells Swift to start here.
/// `@MainActor` means this code always runs on the main (UI) thread.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shared = AppDelegate()  // keep the delegate alive (NSApp only holds it weakly)
    private let music = MusicController()
    private var panelController: NotchPanelController?
    private var menuBarController: MenuBarController?

    static func main() {
        let app = NSApplication.shared
        app.delegate = shared
        // .accessory = no Dock icon and no app menu; matches LSUIElement in Info.plist.
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        music.start()
        let controller = NotchPanelController(music: music)
        controller.show()
        panelController = controller
        menuBarController = MenuBarController()
    }
}
