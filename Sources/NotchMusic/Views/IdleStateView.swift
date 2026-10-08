import SwiftUI

/// Shown when there's no track to display (Music closed, nothing playing, or permission missing).
struct IdleStateView: View {
    let icon: String
    let message: String
    var buttonTitle: String?
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
