import AVFoundation

/// Metadata about an available speech synthesis voice.
///
/// Wraps `AVSpeechSynthesisVoice` properties into a simple value type for display in the voice
/// picker UI. Enhanced and premium voices only appear in `speechVoices()` if the user has
/// downloaded them via Settings > Accessibility > Live Speech > Voices.
struct VoiceInfo: Identifiable {
    /// The voice identifier string used to create an `AVSpeechSynthesisVoice`.
    let identifier: String
    /// Human-readable display name (e.g. "Samantha", "Daniel").
    let name: String
    /// Language code (e.g. "en-US", "en-GB").
    let language: String
    /// Voice quality tier.
    let quality: Quality
    /// Whether the voice is installed and available for use.
    /// Default-quality voices are always installed. Enhanced and premium voices
    /// only appear in `speechVoices()` if downloaded, so they are always installed when visible.
    let isInstalled: Bool

    var id: String { identifier }

    /// Voice quality tiers matching Apple's AVSpeechSynthesisVoice quality levels.
    enum Quality: String, CaseIterable, Comparable {
        case `default`
        case enhanced
        case premium

        static func < (lhs: Quality, rhs: Quality) -> Bool {
            let order: [Quality] = [.default, .enhanced, .premium]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else { return false }
            return lhsIndex < rhsIndex
        }
    }

    /// Creates a VoiceInfo from an AVSpeechSynthesisVoice.
    ///
    /// Maps the voice's quality property to the local Quality enum. Enhanced and premium
    /// voices only appear in `speechVoices()` results when installed, so `isInstalled` is
    /// always true for voices returned by this factory.
    ///
    /// - Parameter voice: An AVSpeechSynthesisVoice from the system.
    /// - Returns: A VoiceInfo capturing the voice's metadata.
    static func from(voice: AVSpeechSynthesisVoice) -> VoiceInfo {
        let quality: Quality
        switch voice.quality {
        case .enhanced:
            quality = .enhanced
        case .premium:
            quality = .premium
        default:
            quality = .default
        }

        return VoiceInfo(
            identifier: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: quality,
            isInstalled: true
        )
    }
}
