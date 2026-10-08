import SwiftUI

/// Single-line text that scrolls sideways when it's too long to fit (like the iOS Music app).
/// Short text just sits still. Each loop pauses briefly at the start so it's readable.
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    var speed: Double = 30      // points per second
    var gap: CGFloat = 36       // space between the end of the text and its repeat
    var pause: Double = 1.6     // seconds to rest at the start of each loop

    @State private var textWidth: CGFloat = 0
    @State private var startDate = Date()

    var body: some View {
        // A hidden, truncated copy gives this view the right height and lets it fill the available width.
        label
            .frame(maxWidth: .infinity, alignment: .leading)
            .hidden()
            .overlay {
                GeometryReader { geo in
                    let overflows = textWidth > geo.size.width + 1
                    TimelineView(.animation(paused: !overflows)) { context in
                        HStack(spacing: gap) {
                            label
                            if overflows { label }  // second copy makes the loop seamless
                        }
                        .fixedSize()
                        .offset(x: overflows ? -offset(at: context.date) : 0)
                    }
                    .frame(width: geo.size.width, alignment: .leading)
                    .clipped()
                    .mask(overflows ? AnyView(edgeFade) : AnyView(Color.black))
                }
            }
            .background(
                // Measure the full, untruncated width of the text.
                label.fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
            )
            .onChange(of: text) { startDate = Date() }  // restart from the beginning for a new song
    }

    private var label: some View {
        Text(text).font(font).foregroundStyle(color).lineLimit(1)
    }

    /// Soft fade at both edges so text doesn't get chopped off abruptly.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.05),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private func offset(at date: Date) -> CGFloat {
        let distance = Double(textWidth + gap)
        let cycle = pause + distance / speed
        let t = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: cycle)
        return t < pause ? 0 : CGFloat((t - pause) * speed)
    }
}
