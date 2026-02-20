import SwiftUI

/// Reusable WPM (words per minute) slider control shared by both RSVP and page reading modes.
///
/// Provides a slider bound to the parent's local slider state (for smooth dragging), with
/// callbacks for continuous changes and drag-end events. The separation of `onWPMChanged`
/// (continuous) and `onWPMChangeEnded` (debounced) prevents audio stuttering when TTS is
/// active -- the RSVPEngine timer updates immediately during drag, but TTS only restarts
/// when the drag ends (Research Pitfall 5 / NAV-01).
///
/// **Design decisions:**
/// - `@Binding var sliderWPM` for smooth local drag state (avoids fighting coordinator updates)
/// - `onEditingChanged` triggers `onWPMChangeEnded` only when `editing` becomes false (drag end)
/// - After drag end, slider snaps to `effectiveWPM` (may differ from requested due to speed cap)
/// - Range: 100-500 WPM, step: 10 WPM (locked decision from CONTEXT.md)
struct WPMSliderView: View {

    /// Local slider value bound to the parent's state for smooth dragging.
    @Binding var sliderWPM: Double

    /// The actual WPM after speed cap, shown as reference.
    let effectiveWPM: Int

    /// Whether the current voice is capping the speed (for potential visual feedback).
    let isSpeedCapped: Bool

    /// Called continuously during slider drag with the current slider value.
    /// Used to update RSVPEngine timer speed immediately.
    let onWPMChanged: (Int) -> Void

    /// Called once when the slider drag ends (onEditingChanged = false).
    /// Used to restart TTS with the new rate (debounced restart).
    let onWPMChangeEnded: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Slider(
                    value: $sliderWPM,
                    in: 100...500,
                    step: 10
                ) {
                    Text("WPM")
                } onEditingChanged: { editing in
                    if !editing {
                        onWPMChangeEnded(Int(sliderWPM))
                        // Snap to effective WPM after cap (locked decision: slider shows reality)
                        sliderWPM = Double(effectiveWPM)
                    }
                }
                .onChange(of: sliderWPM) { _, newValue in
                    onWPMChanged(Int(newValue))
                }

                Text("500")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}
