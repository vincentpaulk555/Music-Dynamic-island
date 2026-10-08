import SwiftUI

/// Four bouncing bars, like the "now playing" indicator in Apple Music.
/// It's decorative: macOS doesn't let apps read Music's audio levels without screen/audio capture permission.
struct WaveformView: View {
    let isPlaying: Bool
    let color: Color

    private let barCount = 4

    var body: some View {
        // TimelineView(.animation) redraws every frame while playing and stops when paused.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                HStack(alignment: .center, spacing: geo.size.width * 0.12) {
                    ForEach(0..<barCount, id: \.self) { bar in
                        Capsule()
                            .fill(color)
                            .frame(height: geo.size.height * level(of: bar, at: time))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// Bar height from 0 to 1. Each bar bounces at its own speed so the motion looks irregular.
    private func level(of bar: Int, at time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 0.25 }
        let speed = 4.2 + Double(bar) * 1.7
        let offset = Double(bar) * 1.3
        let wave = abs(sin(time * speed + offset))
        return CGFloat(0.3 + 0.7 * wave)
    }
}
