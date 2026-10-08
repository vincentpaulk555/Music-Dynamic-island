import SwiftUI

/// Previous / play-pause / next buttons.
struct PlaybackControlsView: View {
    let music: MusicController

    var body: some View {
        HStack(spacing: 14) {
            ControlButton(symbol: "backward.fill", size: 16) { music.previousTrack() }
            ControlButton(symbol: music.state == .playing ? "pause.fill" : "play.fill", size: 24) {
                music.togglePlayPause()
            }
            ControlButton(symbol: "forward.fill", size: 16) { music.nextTrack() }
        }
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))  // smooth play ↔ pause icon swap
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())  // make the whole 32×32 square clickable
        }
        .buttonStyle(.plain)
    }
}
