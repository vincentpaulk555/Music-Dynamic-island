import AppKit

/// Where the notch is on screen.
/// macOS screen coordinates start at the bottom-left corner, so "top" means maxY.
struct NotchGeometry {
    let screen: NSScreen
    /// The notch's rectangle in global screen coordinates.
    let notchFrame: CGRect
    /// False on Macs/displays without a notch. We then fake a notch-sized pill at top-center.
    let hasNotch: Bool

    /// Geometry for the screen with a notch (the built-in display), or the main screen as a fallback.
    static func current() -> NotchGeometry? {
        let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notched ?? NSScreen.main ?? NSScreen.screens.first else { return nil }
        return NotchGeometry(screen: screen)
    }

    init(screen: NSScreen) {
        self.screen = screen
        let frame = screen.frame

        // safeAreaInsets.top = height of the notch strip.
        // auxiliaryTopLeftArea / RightArea = the usable menu-bar areas on either side of the notch,
        // so the notch width is whatever is left over between them.
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let height = screen.safeAreaInsets.top
            let width = frame.width - left.width - right.width
            notchFrame = CGRect(x: frame.midX - width / 2, y: frame.maxY - height,
                                width: width, height: height)
            hasNotch = true
        } else {
            // No notch: use the menu bar height and a typical notch width.
            let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, 24)
            let width: CGFloat = 200
            notchFrame = CGRect(x: frame.midX - width / 2, y: frame.maxY - menuBarHeight,
                                width: width, height: menuBarHeight)
            hasNotch = false
        }
    }
}
