import SwiftUI

/// A heavily blurred copy of the artwork that tints the expanded panel and slowly drifts.
/// The mask keeps the area right under the notch pure black (so it still blends with the real notch)
/// and lets the colors bloom out toward the bottom corners.
struct ArtworkGlowView: View {
    let image: NSImage?

    var body: some View {
        GeometryReader { geo in
            // 30 fps is plenty for motion this slow, and saves battery compared to every frame.
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            // Slow, gentle motion: a full rotation takes ~1 minute,
                            // and the drift/"breathing" cycles take 10–20 seconds.
                            .rotationEffect(.degrees(t * 6))
                            .scaleEffect(1.6 + 0.12 * sin(t * 0.45))
                            .offset(x: geo.size.width * 0.08 * sin(t * 0.3),
                                    y: geo.size.height * 0.1 * cos(t * 0.37))
                            .blur(radius: 34)
                            .saturation(1.4)
                            .id(ObjectIdentifier(image))  // new artwork = new view, so it crossfades
                            .transition(.opacity)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .mask(
                RadialGradient(
                    colors: [.clear, .black.opacity(0.5), .black],
                    center: .top,
                    startRadius: geo.size.height * 0.35,
                    endRadius: geo.size.width * 0.62
                )
            )
            .opacity(0.7)
        }
        .allowsHitTesting(false)
    }
}
