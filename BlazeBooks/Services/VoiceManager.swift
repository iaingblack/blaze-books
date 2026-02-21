import AVFoundation
import UIKit

/// Voice enumeration and management service for the voice picker UI.
///
/// VoiceManager enumerates installed English speech synthesis voices, separates them
/// by quality tier, provides voice preview via a temporary synthesizer, and handles
/// deep-linking to iOS Settings for voice downloads. It observes the
/// `availableVoicesDidChangeNotification` to refresh the voice list when the user
/// returns from Settings after downloading new voices.
///
/// **Locked decisions from CONTEXT.md:**
/// - Flat list of English voices only for v1 (no language/accent grouping)
/// - Two sections: "Installed" at top, "Available for Download" below
/// - Voice preview with short sample phrase on tap
/// - Settings deep-link for voice downloads
@Observable
final class VoiceManager {

    // MARK: - Observable State

    /// Voices currently installed and available on the device, filtered to English only.
    /// Sorted by quality tier (premium first, then enhanced, then default) and name.
    var installedVoices: [VoiceInfo] = []

    /// Guidance text for downloading additional voices.
    /// Apple provides no API to list uninstalled voices, so we show a guidance card instead.
    var downloadGuidanceMessage: String = "More voices are available in Settings > Accessibility > Live Speech > Voices"

    /// The currently selected voice for TTS playback.
    var selectedVoice: VoiceInfo?

    // MARK: - Private State

    /// Notification observer for voice availability changes.
    @ObservationIgnored
    private var notificationObserver: (any NSObjectProtocol)?

    /// Temporary synthesizer used for voice preview playback.
    @ObservationIgnored
    private var previewSynthesizer: AVSpeechSynthesizer?

    /// UserDefaults key for persisting the selected voice identifier.
    @ObservationIgnored
    private static let selectedVoiceKey = "BlazeBooks.selectedVoiceIdentifier"

    // MARK: - Initialization

    init() {
        startObservingVoiceChanges()
        loadVoices()
        loadSelectedVoice()
    }

    deinit {
        stopObservingVoiceChanges()
    }

    // MARK: - Public Methods

    /// Enumerates installed speech synthesis voices, filtering to English only.
    ///
    /// Calls `AVSpeechSynthesisVoice.speechVoices()` and filters to voices whose
    /// language code starts with "en". Excludes novelty voices where detectable.
    /// Maps each to `VoiceInfo` and sorts by quality tier (premium first) then name.
    ///
    /// Since Apple provides no API to list uninstalled/downloadable voices, the
    /// "Available for Download" section is replaced with a guidance card directing
    /// users to Settings > Accessibility > Live Speech > Voices.
    func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Filter to English voices only (locked decision: flat English list for v1)
        let englishVoices = allVoices.filter { voice in
            guard voice.language.hasPrefix("en") else { return false }

            // Exclude novelty voices if the trait is available
            if voice.voiceTraits.contains(.isNoveltyVoice) {
                return false
            }

            return true
        }

        // Map to VoiceInfo and sort: premium > enhanced > default, then alphabetical
        installedVoices = englishVoices
            .map { VoiceInfo.from(voice: $0) }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality {
                    return lhs.quality > rhs.quality // Premium first
                }
                return lhs.name < rhs.name
            }
    }

    /// Selects a voice for TTS playback and persists the choice to UserDefaults.
    ///
    /// - Parameter voice: The voice to select.
    func selectVoice(_ voice: VoiceInfo) {
        selectedVoice = voice
        UserDefaults.standard.set(voice.identifier, forKey: Self.selectedVoiceKey)
    }

    /// Previews a voice by speaking a short sample phrase.
    ///
    /// Creates a temporary AVSpeechSynthesizer (separate from TTSService) and
    /// speaks a fixed sample phrase using the specified voice. Stops any currently
    /// playing preview first.
    ///
    /// - Parameter voice: The voice to preview.
    func previewVoice(_ voice: VoiceInfo) {
        // Stop any currently playing preview
        previewSynthesizer?.stopSpeaking(at: .immediate)

        previewSynthesizer = AVSpeechSynthesizer()
        previewSynthesizer?.usesApplicationAudioSession = false

        let utterance = AVSpeechUtterance(string: "The quick brown fox jumps over the lazy dog.")
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice.identifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        previewSynthesizer?.speak(utterance)
    }

    /// Opens iOS Settings so users can navigate to Accessibility → Spoken Content → Voices
    /// to download additional voices.
    func openVoiceSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    /// Registers for `AVSpeechSynthesizer.availableVoicesDidChangeNotification` to
    /// automatically refresh the voice list when voices are downloaded or removed.
    ///
    /// Observes on the main queue so UI updates happen immediately.
    func startObservingVoiceChanges() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadVoices()
        }
    }

    /// Removes the voice change notification observer.
    func stopObservingVoiceChanges() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }

    /// Loads the previously selected voice from UserDefaults.
    ///
    /// If a saved voice identifier is found and still available in the installed voices,
    /// sets it as selectedVoice. Otherwise defaults to the first installed voice.
    func loadSelectedVoice() {
        if let savedId = UserDefaults.standard.string(forKey: Self.selectedVoiceKey),
           let savedVoice = installedVoices.first(where: { $0.identifier == savedId }) {
            selectedVoice = savedVoice
        } else {
            selectedVoice = installedVoices.first
        }
    }
}
