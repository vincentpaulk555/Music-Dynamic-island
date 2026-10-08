import AppKit
import SwiftUI

/// A panel that can never become the key or main window, so it never steals keyboard focus.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that accepts the very first click, so buttons work without "focusing" the panel first.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Creates the floating notch window, keeps it positioned over the notch,
/// and expands/collapses it based on where the mouse is.
@MainActor
final class NotchPanelController {
    /// Spare room around the expanded shape so the spring's slight overshoot isn't clipped.
    private let windowMargin = CGSize(width: 40, height: 20)
    /// How long the mouse must be outside before collapsing (prevents flicker).
    private let collapseDelay: Duration = .milliseconds(100)
    private let openSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    /// Closing is a bit quicker and less bouncy, so it gets out of the way.
    private let closeSpring = Animation.spring(response: 0.32, dampingFraction: 0.9)

    private let panel: NotchPanel
    private let model: NotchViewModel
    private let music: MusicController
    private var geometry: NotchGeometry?
    private var hoverMonitor: HoverMonitor?
    private var collapseTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?

    init(music: MusicController) {
        self.music = music
        model = NotchViewModel(music: music)
        panel = NotchPanel(
            contentRect: .zero,
            // borderless = no title bar; nonactivatingPanel = clicking it won't activate our app.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Window "level" = stacking order. mainMenu + 3 puts us above the menu bar.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        // Show on every Space (desktop) and alongside full-screen apps; don't appear in Cmd-Tab / Mission Control.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        // While collapsed, let every click pass straight through to whatever is underneath.
        panel.ignoresMouseEvents = true

        // NSHostingView lets an AppKit window display a SwiftUI view.
        let hostingView = NotchHostingView(rootView: NotchView(model: model))
        hostingView.sizingOptions = []      // we size the window ourselves; don't let SwiftUI resize it
        hostingView.safeAreaRegions = []    // don't push content down to avoid the notch
        panel.contentView = hostingView

        // Reposition when displays are plugged in/out or resolution changes.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateFrame() }
        }

        hoverMonitor = HoverMonitor { [weak self] point in
            self?.handleMouseMoved(to: point)
        }
    }

    func show() {
        updateFrame()
        panel.orderFrontRegardless()  // show without activating the app
        hoverMonitor?.start()
    }

    // MARK: - Layout

    /// The window is always the expanded size, anchored to the top-center of the notch screen.
    /// SwiftUI draws the black shape smaller or larger inside it.
    private func updateFrame() {
        guard let geometry = NotchGeometry.current() else { return }
        self.geometry = geometry
        model.notchSize = geometry.notchFrame.size

        let width = max(model.expandedSize.width, geometry.notchFrame.width) + windowMargin.width
        let height = model.expandedSize.height + windowMargin.height
        let frame = CGRect(x: geometry.notchFrame.midX - width / 2,
                           y: geometry.screen.frame.maxY - height,
                           width: width, height: height)
        panel.setFrame(frame, display: true)
    }

    // MARK: - Hover

    /// Area that triggers expanding: the collapsed shape (notch, or notch + compact ears) plus a little slack.
    /// Extended 2pt above the screen top because CGRect.contains excludes its top edge,
    /// and the mouse sits exactly on that edge when pushed against the top of the screen.
    private func hoverZone(_ g: NotchGeometry) -> CGRect {
        let size = model.collapsedSize
        let top = g.screen.frame.maxY
        return CGRect(x: g.notchFrame.midX - size.width / 2 - 6, y: top - size.height,
                      width: size.width + 12, height: size.height + 2)
    }

    /// Area that keeps the panel open once expanded: the whole expanded shape.
    private func expandedZone(_ g: NotchGeometry) -> CGRect {
        let size = model.expandedSize
        let top = g.screen.frame.maxY
        return CGRect(x: g.notchFrame.midX - size.width / 2, y: top - size.height,
                      width: size.width, height: size.height + 2)
    }

    private func handleMouseMoved(to point: NSPoint) {
        guard let geometry else { return }
        let zone = model.isExpanded ? expandedZone(geometry) : hoverZone(geometry)

        if zone.contains(point) {
            // Mouse is inside: cancel any pending collapse and expand if needed.
            collapseTask?.cancel()
            collapseTask = nil
            if !model.isExpanded { setExpanded(true) }
        } else if model.isExpanded && collapseTask == nil && NSEvent.pressedMouseButtons == 0 {
            // (Skipped while a mouse button is held, so dragging the time bar past the edge doesn't close the panel.)
            // Mouse left: wait a moment before collapsing, in case it comes right back.
            collapseTask = Task { [weak self, collapseDelay] in
                try? await Task.sleep(for: collapseDelay)
                guard !Task.isCancelled, let self else { return }
                self.collapseTask = nil
                self.setExpanded(false)
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        // Only accept clicks while open; when closed the menu bar underneath stays fully usable.
        panel.ignoresMouseEvents = !expanded
        if expanded { music.refresh() }  // resync position in case you skipped around inside Music
        withAnimation(expanded ? openSpring : closeSpring) {
            model.isExpanded = expanded
        }
    }
}
