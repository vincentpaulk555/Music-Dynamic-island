import SwiftUI

/// Elapsed time, progress bar, and remaining time.
/// Click anywhere on the bar to jump there, or drag along it to scrub; the bar thickens while dragging.
/// `TimelineView` redraws this every half second; the position is calculated locally, not fetched.
struct TrackProgressView: View {
    let music: MusicController

    /// Where the user is dragging (0…1), or nil when not touching the bar.
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = music.track?.duration ?? 0
            let livePosition = music.position(at: context.date)
            // While dragging, show the drag position instead of the playing position.
            let position = dragFraction.map { $0 * duration } ?? livePosition
            let fraction = duration > 0 ? position / duration : 0

            HStack(spacing: 8) {
                Text(Self.format(position))
                    .frame(width: 36, alignment: .leading)

                bar(fraction: fraction, duration: duration)

                Text("-" + Self.format(max(duration - position, 0)))
                    .frame(width: 36, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func bar(fraction: Double, duration: Double) -> some View {
        let isScrubbing = dragFraction != nil
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(music.accentColor)
                    .frame(width: max(geo.size.width * fraction, 0))
            }
            .frame(height: isScrubbing ? 8 : 4)
            .frame(maxHeight: .infinity)      // centered in a taller, easier-to-hit area
            .contentShape(Rectangle())        // the whole 16pt-tall strip responds to clicks
            .gesture(
                // minimumDistance 0 = a plain click counts too, not just a drag.
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = Self.clamp(value.location.x / geo.size.width)
                    }
                    .onEnded { value in
                        let target = Self.clamp(value.location.x / geo.size.width)
                        if duration > 0 { music.seek(to: target * duration) }
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 16)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isScrubbing)
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    /// 125 seconds → "2:05"
    private static func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
