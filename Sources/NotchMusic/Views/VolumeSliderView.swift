import SwiftUI

/// Small speaker icon + slider for Music's volume.
/// Click or drag the bar to set the volume; click the speaker to mute/unmute.
/// (A custom slider, because the standard macOS Slider looks grayed out in a window that isn't focused.)
struct VolumeSliderView: View {
    let music: MusicController
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 6) {
            Button { music.toggleMute() } label: {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 18, height: 18, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(music.accentColor)
                        .frame(width: geo.size.width * music.volume / 100)
                }
                .frame(height: isDragging ? 6 : 4)
                .frame(maxHeight: .infinity)   // centered in a taller, easier-to-hit area
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            music.setVolume(Double(value.location.x / geo.size.width) * 100)
                        }
                        .onEnded { _ in isDragging = false }
                )
            }
            .frame(height: 16)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
        }
    }

    /// Speaker with 0–3 waves depending on the level.
    private var icon: String {
        switch music.volume {
        case 0: "speaker.slash.fill"
        case ..<34: "speaker.wave.1.fill"
        case ..<67: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}
