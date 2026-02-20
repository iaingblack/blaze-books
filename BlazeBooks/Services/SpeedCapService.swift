import AVFoundation

/// Per-voice WPM calibration and capping service.
///
/// Each Apple TTS voice has a natural maximum WPM beyond which audio becomes garbled.
/// SpeedCapService detects this cap per voice and clamps WPM gracefully. When the user's
/// requested WPM exceeds the voice's capability, the effective WPM is clamped and the
/// difference is surfaced via observable state for an inline banner in the reading view.
///
/// **Locked decisions from CONTEXT.md:**
/// - Per-voice speed cap (not global)
/// - Slider snaps to actual capped WPM (shows reality)
/// - Silent RSVP (no TTS) capped at slider max of 500 WPM
///
/// **Rate conversion:**
/// AVSpeechUtterance rate 0.5 (default) maps to approximately 180 WPM.
/// Linear interpolation: `rate = 0.5 * (wpm / 180.0)`, clamped to 0.0-1.0.
/// This is an approximation -- exact calibration requires empirical testing (open question from research).
@Observable
final class SpeedCapService {

    // MARK: - Observable State

    /// The effective WPM cap for the current voice.
    var cappedWPM: Int = 500
    /// Whether the current voice is capping the requested WPM.
    var isCapped: Bool = false

    // MARK: - Private State

    /// Cache mapping voice identifier to empirically determined max WPM.
    /// Pre-populated with conservative defaults per quality tier.
    @ObservationIgnored
    private var voiceCapCache: [String: Int] = [:]

    // MARK: - Public Methods

    /// Returns the maximum WPM for the given voice.
    ///
    /// If the voice has been calibrated (stored in cache), returns the cached value.
    /// Otherwise, returns a conservative default based on the voice's quality tier:
    /// - Default quality: 300 WPM
    /// - Enhanced quality: 350 WPM
    /// - Premium quality: 400 WPM
    ///
    /// These are starting estimates that can be refined via `updateCap(forVoice:maxWPM:)`.
    ///
    /// - Parameter identifier: The AVSpeechSynthesisVoice identifier string.
    /// - Returns: The maximum WPM this voice can handle clearly.
    func maxWPM(forVoice identifier: String) -> Int {
        if let cached = voiceCapCache[identifier] {
            return cached
        }

        // Determine quality tier from the actual voice if available
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            switch voice.quality {
            case .premium:
                return 400
            case .enhanced:
                return 350
            default:
                return 300
            }
        }

        // Fallback: conservative default
        return 300
    }

    /// Returns the effective WPM after capping for the given voice.
    ///
    /// Simple clamp: `min(requested, maxWPM(forVoice:))`.
    ///
    /// - Parameters:
    ///   - requested: The user's desired WPM.
    ///   - identifier: The AVSpeechSynthesisVoice identifier string.
    /// - Returns: The effective WPM that should be applied.
    func effectiveWPM(requested: Int, forVoice identifier: String) -> Int {
        return min(requested, maxWPM(forVoice: identifier))
    }

    /// Converts WPM to AVSpeechUtterance rate (0.0-1.0 range).
    ///
    /// Baseline mapping: rate 0.5 (AVSpeechUtteranceDefaultSpeechRate) ~ 180 WPM.
    /// Linear interpolation: `rate = 0.5 * (wpm / 180.0)`, clamped to valid range.
    ///
    /// This is an approximation. The actual WPM varies per voice and is nonlinear
    /// at extreme rates. Empirical calibration can refine this via `updateCap(forVoice:maxWPM:)`.
    ///
    /// - Parameters:
    ///   - wpm: The target words per minute.
    ///   - identifier: The AVSpeechSynthesisVoice identifier (reserved for future per-voice tuning).
    /// - Returns: The AVSpeechUtterance rate value.
    func wpmToRate(_ wpm: Int, forVoice identifier: String) -> Float {
        let rate = Float(0.5 * (Double(wpm) / 180.0))
        return max(AVSpeechUtteranceMinimumSpeechRate,
                   min(rate, AVSpeechUtteranceMaximumSpeechRate))
    }

    /// Converts an AVSpeechUtterance rate back to approximate WPM.
    ///
    /// Inverse of `wpmToRate`: `wpm = rate / 0.5 * 180`.
    ///
    /// - Parameters:
    ///   - rate: The AVSpeechUtterance rate value (0.0-1.0).
    ///   - identifier: The AVSpeechSynthesisVoice identifier (reserved for future per-voice tuning).
    /// - Returns: The approximate WPM for this rate.
    func rateToWPM(_ rate: Float, forVoice identifier: String) -> Int {
        let wpm = Double(rate) / 0.5 * 180.0
        return max(100, min(500, Int(wpm.rounded())))
    }

    /// Updates the cached speed cap for a voice with an empirically measured maximum.
    ///
    /// Called after calibration testing determines the actual maximum WPM for a voice.
    ///
    /// - Parameters:
    ///   - identifier: The AVSpeechSynthesisVoice identifier string.
    ///   - maxWPM: The empirically determined maximum WPM.
    func updateCap(forVoice identifier: String, maxWPM: Int) {
        voiceCapCache[identifier] = maxWPM
    }
}
