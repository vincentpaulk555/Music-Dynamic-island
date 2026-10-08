import SwiftUI

/// The black shape drawn inside the notch panel. Three looks:
/// - plain: matches the physical notch (nothing playing)
/// - compact: notch with artwork + waveform "ears" (playing, not hovered)
/// - expanded: the full player, grown down and out like Dynamic Island (hovered)
struct NotchView: View {
    let model: NotchViewModel
    private var music: MusicController { model.music }

    var body: some View {
        let size = model.currentSize
        let radius: CGFloat = model.isExpanded ? 26 : (model.isCompact ? 12 : 10)
        // Square top corners (flush with the screen edge), rounded bottom corners.
        let shape = UnevenRoundedRectangle(
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            style: .continuous
        )

        ZStack(alignment: .top) {
            shape.fill(.black)

            if model.isExpanded {
                ArtworkGlowView(image: music.artwork)
                    .transition(.opacity)
                MusicPlayerView(music: music, notchSize: model.notchSize, panelSize: model.expandedSize)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                if music.track != nil {
                    BorderGlowView(shape: shape, color: music.accentColor)
                        .transition(.opacity)
                }
            } else if model.isCompact {
                CompactActivityView(music: music, height: model.notchSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)  // keep content inside the shape while it animates
        .shadow(color: .black.opacity(model.isExpanded ? 0.4 : 0), radius: 10, y: 4)
        // Pin the shape to the top-center of the (larger, transparent) window.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Animate into/out of compact when playback starts or stops.
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: music.isPlayingTrack)
        .ignoresSafeArea()
    }
}
