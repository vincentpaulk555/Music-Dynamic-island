import SwiftUI
import Observation

/// Shared state between the window controller (AppKit) and the views (SwiftUI).
/// `@Observable` makes SwiftUI redraw automatically whenever a property here changes.
@MainActor
@Observable
final class NotchViewModel {
    let music: MusicController
    var isExpanded = false
    /// Size of the physical notch.
    var notchSize = CGSize(width: 200, height: 32)
    /// Size of the panel when hovered.
    let expandedSize = CGSize(width: 500, height: 160)

    init(music: MusicController) {
        self.music = music
    }

    /// Collapsed while a song plays: small artwork left of the notch, waveform on the right.
    var isCompact: Bool { !isExpanded && music.isPlayingTrack }

    /// Notch plus a square "ear" on each side.
    var compactSize: CGSize {
        CGSize(width: notchSize.width + 2 * (notchSize.height + 14), height: notchSize.height)
    }

    /// Size when not hovered: compact while playing, otherwise exactly the notch.
    var collapsedSize: CGSize { music.isPlayingTrack ? compactSize : notchSize }

    var currentSize: CGSize { isExpanded ? expandedSize : collapsedSize }
}
