import SwiftUI

/// Album artwork with rounded corners, or a music-note placeholder while it loads / if there is none.
struct ArtworkView: View {
    let image: NSImage?
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            Color.white.opacity(0.12)
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(ObjectIdentifier(image))  // new artwork = new view, so it crossfades
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
