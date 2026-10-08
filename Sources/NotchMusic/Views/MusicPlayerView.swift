import SwiftUI

/// Content of the expanded panel: the player, or an idle message when there's nothing to show.
struct MusicPlayerView: View {
    let music: MusicController
    let notchSize: CGSize
    let panelSize: CGSize

    var body: some View {
        if music.needsPermission {
            IdleStateView(icon: "lock.fill",
                          message: "Allow NotchMusic to control Music",
                          buttonTitle: "Open Settings") { music.openAutomationSettings() }
                .padding(.top, notchSize.height)
        } else if music.state == .notRunning {
            IdleStateView(icon: "music.note",
                          message: "Apple Music isn't running",
                          buttonTitle: "Open Music") { music.openMusic() }
                .padding(.top, notchSize.height)
        } else if let track = music.track {
            ZStack(alignment: .topLeading) {
                NowPlayingView(music: music, track: track, notchSize: notchSize, panelSize: panelSize)
                // The strip right of the notch: waveform (same spot as in compact mode) + volume.
                let notchRight = (panelSize.width + notchSize.width) / 2
                HStack(spacing: 12) {
                    WaveformView(isPlaying: music.state == .playing, color: music.accentColor)
                        .frame(width: notchSize.height - 12, height: notchSize.height - 16)
                    VolumeSliderView(music: music)
                }
                .frame(width: panelSize.width - notchRight - 14 - 16, height: notchSize.height)
                .offset(x: notchRight + 14)
            }
        } else {
            IdleStateView(icon: "music.note", message: "Nothing playing")
                .padding(.top, notchSize.height)
        }
    }
}

/// Layout:
/// ┌──────────┬───notch───┬──────────────────┐
/// │          └───────────┘ ▂▅▃▆  🔈━━━━    │
/// │ artwork   Title Name        ⏮  ⏯  ⏭    │
/// │           Artist                        │
/// │           0:42 ━━━━━━━━━━━━━━━━ -2:13   │
/// └─────────────────────────────────────────┘
/// The artwork fills the space left of the notch; the title row is centered on the artwork,
/// and the time bar lines up with the bottom of the artwork.
private struct NowPlayingView: View {
    let music: MusicController
    let track: Track
    let notchSize: CGSize
    let panelSize: CGSize

    private let padding: CGFloat = 16

    /// As big as fits: limited by the panel height and by the gap between the panel edge and the notch.
    private var artworkSize: CGFloat {
        let byHeight = panelSize.height - 2 * padding
        let byWidth = (panelSize.width - notchSize.width) / 2 - padding - 10
        return min(byHeight, byWidth)
    }

    var body: some View {
        HStack(alignment: .top, spacing: padding) {
            ArtworkView(image: music.artwork, cornerRadius: 14)
                .frame(width: artworkSize, height: artworkSize)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 3)

            ZStack {
                // Title row sits on the artwork's horizontal center line…
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        MarqueeText(text: track.title,
                                    font: .system(size: 18, weight: .bold),
                                    color: .white)
                        MarqueeText(text: track.artist,
                                    font: .system(size: 13),
                                    color: .white.opacity(0.65))
                    }
                    PlaybackControlsView(music: music)
                }
                // …and the time bar lines up with the artwork's bottom edge.
                VStack {
                    Spacer(minLength: 0)
                    TrackProgressView(music: music)
                }
            }
            .frame(height: artworkSize)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
