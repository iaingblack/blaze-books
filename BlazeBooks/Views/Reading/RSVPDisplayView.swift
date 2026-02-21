import SwiftUI

/// ORP-aligned single word display for RSVP (Rapid Serial Visual Presentation) reading.
///
/// Renders one word at a time with the Optimal Recognition Point (ORP) character anchored
/// at the horizontal center of the view, highlighted in the app's accent color. The word
/// is split into three segments: before ORP (right-aligned), ORP character (centered, bold),
/// and after ORP (left-aligned). A thin vertical guide line marks the ORP position.
///
/// **Design decisions:**
/// - Monospaced font for consistent character width and reliable ORP alignment
/// - No animation between words -- instant swap for comfortable high-speed reading
/// - Dark background for reduced eye strain during extended RSVP sessions
/// - Vertical guide line provides a subtle fixation anchor for the eye
///
/// **Dark mode behavior:** The RSVP view intentionally uses a fixed dark background
/// (`Color.black`) regardless of system appearance. This is a deliberate design choice
/// for reading comfort during rapid word display, following the precedent set by Spritz
/// and similar RSVP readers. The app chrome (navigation bars, controls, chapter navigation)
/// follows the system dark/light mode setting automatically via SwiftUI semantic colors.
struct RSVPDisplayView: View {

    /// The current word to display, with pre-calculated ORP segments.
    /// When nil, shows a subtle idle indicator.
    let word: ORPWord?

    /// User-adjustable font size for RSVP word display.
    var fontSize: CGFloat = 36

    /// Approximate width of a single monospaced character, scaled to font size.
    /// Monospaced characters are roughly 0.6x the font size in width.
    private var characterWidth: CGFloat { fontSize * 0.6 }

    var body: some View {
        GeometryReader { geometry in
            let halfWidth = geometry.size.width / 2
            let halfChar = characterWidth / 2

            ZStack {
                // Dark background for comfortable RSVP reading
                Color.black

                // Vertical guide line at ORP position (subtle fixation anchor)
                Rectangle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 1.5)
                    .position(x: halfWidth, y: geometry.size.height / 2)

                if let word = word {
                    // ORP-aligned word display
                    HStack(spacing: 0) {
                        // Before ORP: right-aligned in left half
                        Text(word.beforeORP)
                            .foregroundStyle(.white)
                            .frame(width: halfWidth - halfChar, alignment: .trailing)

                        // ORP character: accent color, bold, fixed center position
                        Text(word.orpCharacter)
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.bold)
                            .frame(width: characterWidth, alignment: .center)

                        // After ORP: left-aligned in right half
                        Text(word.afterORP)
                            .foregroundStyle(.white)
                            .frame(width: halfWidth - halfChar, alignment: .leading)
                    }
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .position(x: halfWidth, y: geometry.size.height / 2)
                } else {
                    // Idle state: subtle dash indicator
                    Text("--")
                        .font(.system(size: fontSize, weight: .light, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .position(x: halfWidth, y: geometry.size.height / 2)
                }
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // Disable animations -- RSVP must swap words instantly
        .transaction { $0.animation = nil }
    }
}
