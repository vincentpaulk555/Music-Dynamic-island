import SwiftUI

/// A soft glow in the artwork's accent color along the panel's edges.
/// It fades out toward the top so the panel still blends seamlessly into the physical notch.
struct BorderGlowView<S: InsettableShape>: View {
    let shape: S
    let color: Color

    var body: some View {
        ZStack {
            // Wide blurred stroke = the glow; thin stroke on top = a crisp rim.
            shape.inset(by: 3).stroke(color, lineWidth: 6).blur(radius: 6).opacity(0.55)
            shape.inset(by: 0.5).stroke(color.opacity(0.7), lineWidth: 1)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.4), location: 0.35),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }
}
