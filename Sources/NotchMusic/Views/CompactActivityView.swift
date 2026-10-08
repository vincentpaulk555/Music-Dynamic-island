import SwiftUI

/// Shown beside the notch while music plays: small artwork on the left, waveform on the right.
/// The middle stays empty because it sits behind the physical notch.
struct CompactActivityView: View {
    let music: MusicController
    let height: CGFloat

    var body: some View {
        HStack {
            ArtworkView(image: music.artwork, cornerRadius: 6)
                .frame(width: height - 10, height: height - 10)
            Spacer()
            WaveformView(isPlaying: music.state == .playing, color: music.accentColor)
                .frame(width: height - 12, height: height - 16)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
    }
}
