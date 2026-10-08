import AppKit

/// Reports the mouse position every time the mouse moves, anywhere on screen.
///
/// - A *global* monitor sees events headed to other apps (the usual case: you're in Safari, etc.).
/// - A *local* monitor sees events headed to our own app.
/// Together they catch every move. Watching mouse movement doesn't need any permission.
@MainActor
final class HoverMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onMove: @MainActor (NSPoint) -> Void

    init(onMove: @escaping @MainActor (NSPoint) -> Void) {
        self.onMove = onMove
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.report() }
            return event  // pass the event on unchanged
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func report() {
        // mouseLocation is in global screen coordinates, same as NotchGeometry.
        onMove(NSEvent.mouseLocation)
    }
}
