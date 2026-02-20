import SwiftUI

/// Inline non-disruptive banner showing that TTS voice speed is capped.
///
/// Appears when the user's requested WPM exceeds the current voice's capability.
/// Shows the actual capped WPM with an info icon on a subtle yellow/orange background.
///
/// **Locked decisions from CONTEXT.md:**
/// - Inline banner in reading view (non-disruptive, stays visible)
/// - Slider snaps to actual capped WPM (shows reality)
/// - Per-voice speed cap
struct SpeedCapBanner: View {

    /// The message to display, e.g. "Voice capped at 320 WPM".
    let message: String

    /// Whether the banner should be visible.
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)

                Text(message)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.12))
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
