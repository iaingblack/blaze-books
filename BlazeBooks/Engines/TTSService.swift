import AVFoundation
import NaturalLanguage

/// AVSpeechSynthesizer wrapper with sentence-level chunking and word-boundary tracking.
///
/// TTSService handles speech synthesis for chapter text by splitting it into individual sentences
/// (one `AVSpeechUtterance` per sentence) to avoid the iOS 17+ silent truncation bug with long
/// utterances. It tracks the global word index across all sentences using cumulative word offsets
/// and reports word boundaries via a callback for the ReadingCoordinator to drive RSVP display.
///
/// **Key design decisions:**
/// - **Sentence-level chunking:** Mandatory for iOS 17+ reliability (Pitfall 1 from research)
/// - **Synthesizer recreation:** Created fresh per chapter; nil'd after stop (Pitfall 2)
/// - **NSObject delegate bridge:** Inner `DelegateHandler` class since @Observable cannot inherit NSObject (Pattern 4)
/// - **MainActor dispatch:** All delegate callbacks dispatch to MainActor before updating @Observable state (Pitfall 4)
/// - **One sentence at a time:** Only queues the current sentence, not the full chapter (anti-pattern avoidance)
@Observable
final class TTSService {

    // MARK: - Observable State

    /// Whether the synthesizer is currently speaking.
    var isSpeaking: Bool = false
    /// The current global word index across all sentences in the chapter.
    var currentGlobalWordIndex: Int = 0

    // MARK: - Private State

    @ObservationIgnored
    private var synthesizer: AVSpeechSynthesizer?
    @ObservationIgnored
    private var delegateHandler: DelegateHandler!
    @ObservationIgnored
    private var sentenceQueue: [(text: String, wordOffset: Int)] = []
    @ObservationIgnored
    private var currentSentenceIndex: Int = 0
    @ObservationIgnored
    private var selectedVoiceIdentifier: String?

    /// Public read-only accessor for the currently selected voice identifier.
    /// Used by ReadingCoordinator to query speed cap for the active voice.
    var currentVoiceIdentifier: String? { selectedVoiceIdentifier }
    @ObservationIgnored
    private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate

    /// Called with the global word index each time the synthesizer reaches a new word.
    /// The ReadingCoordinator uses this to update RSVP display in TTS-on mode.
    @ObservationIgnored
    var onWordBoundary: ((Int) -> Void)?

    /// Called when all sentences in the chapter have been spoken.
    @ObservationIgnored
    var onChapterComplete: (() -> Void)?

    // MARK: - Initialization

    init() {
        delegateHandler = DelegateHandler(owner: self)
    }

    // MARK: - Chapter Preparation

    /// Splits chapter text into sentences with cumulative word offsets for global word tracking.
    ///
    /// Uses `NLTokenizer(unit: .sentence)` pinned to `.english` for consistency with `WordTokenizer`.
    /// Word counts per sentence use `NLTokenizer(unit: .word)` to match the tokenization used
    /// throughout the app (not `String.split` which handles edge cases differently).
    ///
    /// - Parameter text: The full plain text of a chapter.
    func prepareChapter(_ text: String) {
        // Sentence tokenization
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        sentenceTokenizer.setLanguage(.english)

        var sentences: [(text: String, wordOffset: Int)] = []
        var cumulativeWordCount = 0

        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentenceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentenceText.isEmpty else { return true }

            sentences.append((text: sentenceText, wordOffset: cumulativeWordCount))

            // Count words using NLTokenizer for consistency with WordTokenizer
            let wordTokenizer = NLTokenizer(unit: .word)
            wordTokenizer.string = sentenceText
            wordTokenizer.setLanguage(.english)
            var wordCount = 0
            wordTokenizer.enumerateTokens(in: sentenceText.startIndex..<sentenceText.endIndex) { _, _ in
                wordCount += 1
                return true
            }
            cumulativeWordCount += wordCount

            return true
        }

        sentenceQueue = sentences
        currentSentenceIndex = 0
        currentGlobalWordIndex = 0
    }

    // MARK: - Playback Controls

    /// Starts speaking from the sentence containing the given global word index.
    ///
    /// Creates a fresh `AVSpeechSynthesizer` instance (per anti-pattern: recreate, don't reuse)
    /// and sets `usesApplicationAudioSession = false` per WWDC 2020 recommendation.
    ///
    /// - Parameter fromWordIndex: The global word index to start speaking from.
    func speak(fromWordIndex: Int) {
        guard !sentenceQueue.isEmpty else { return }

        // Find the sentence containing this word index
        var targetSentenceIndex = 0
        for (index, _) in sentenceQueue.enumerated() {
            if index + 1 < sentenceQueue.count {
                if sentenceQueue[index + 1].wordOffset > fromWordIndex {
                    targetSentenceIndex = index
                    break
                }
            } else {
                // Last sentence
                targetSentenceIndex = index
            }
        }

        currentSentenceIndex = targetSentenceIndex
        currentGlobalWordIndex = fromWordIndex

        // Create fresh synthesizer per chapter/start (per Pitfall 2)
        synthesizer = AVSpeechSynthesizer()
        synthesizer?.usesApplicationAudioSession = false
        synthesizer?.delegate = delegateHandler

        isSpeaking = true
        speakNextSentence()
    }

    /// Pauses speech at the current word. Keeps the synthesizer alive
    /// (pause is safe; only stop corrupts the synthesizer).
    func pause() {
        synthesizer?.pauseSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// Resumes speech from where it was paused.
    func resume() {
        if synthesizer?.continueSpeaking() == true {
            isSpeaking = true
        }
    }

    /// Stops speech and destroys the synthesizer instance.
    /// Per Pitfall 2: after stopSpeaking, the synthesizer must be recreated.
    func stop() {
        synthesizer?.stopSpeaking(at: .immediate)
        synthesizer?.delegate = nil
        synthesizer = nil
        isSpeaking = false
    }

    /// Sets the voice identifier to use for subsequent utterances.
    ///
    /// - Parameter identifier: The `AVSpeechSynthesisVoice` identifier string.
    func setVoice(identifier: String) {
        selectedVoiceIdentifier = identifier
    }

    /// Sets the speech rate for subsequent utterances.
    ///
    /// - Parameter rate: A value from 0.0 (slowest) to 1.0 (fastest).
    func setRate(_ rate: Float) {
        speechRate = max(0.0, min(1.0, rate))
    }

    // MARK: - Private Methods

    /// Speaks the current sentence in the queue. Only queues ONE sentence at a time
    /// (per anti-pattern: don't queue many utterances).
    private func speakNextSentence() {
        guard currentSentenceIndex < sentenceQueue.count else {
            isSpeaking = false
            onChapterComplete?()
            return
        }

        let sentence = sentenceQueue[currentSentenceIndex]
        let utterance = AVSpeechUtterance(string: sentence.text)

        // Configure voice
        if let voiceId = selectedVoiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceId)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        // Configure rate and timing
        utterance.rate = speechRate
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.05 // Tiny gap between sentences for natural flow

        synthesizer?.speak(utterance)
    }

    /// Converts a character range within a sentence to a word index.
    ///
    /// Counts `NLTokenizer` word tokens that start before the given character position
    /// in the sentence text, consistent with the WordTokenizer approach used throughout.
    ///
    /// - Parameters:
    ///   - range: The NSRange of the character range being spoken.
    ///   - text: The full sentence text.
    /// - Returns: The zero-based word index within this sentence.
    private func wordIndexFromCharRange(_ range: NSRange, in text: String) -> Int {
        guard let swiftRange = Range(range, in: text) else { return 0 }

        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = text
        wordTokenizer.setLanguage(.english)

        var wordIndex = 0
        wordTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            if tokenRange.lowerBound >= swiftRange.lowerBound {
                return false // Stop counting
            }
            wordIndex += 1
            return true
        }

        return wordIndex
    }

    // MARK: - Delegate Handler

    /// Inner NSObject class that bridges AVSpeechSynthesizerDelegate callbacks to the @Observable TTSService.
    ///
    /// Required because @Observable classes cannot inherit from NSObject, but
    /// AVSpeechSynthesizerDelegate requires NSObject conformance.
    private class DelegateHandler: NSObject, AVSpeechSynthesizerDelegate {
        weak var owner: TTSService?

        init(owner: TTSService) {
            self.owner = owner
            super.init()
        }

        func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            willSpeakRangeOfSpeechString characterRange: NSRange,
            utterance: AVSpeechUtterance
        ) {
            guard let owner = owner else { return }

            let sentenceText = utterance.speechString
            let localWordIndex = owner.wordIndexFromCharRange(characterRange, in: sentenceText)
            let sentenceOffset = owner.sentenceQueue[owner.currentSentenceIndex].wordOffset
            let globalIndex = sentenceOffset + localWordIndex

            Task { @MainActor in
                owner.currentGlobalWordIndex = globalIndex
                owner.onWordBoundary?(globalIndex)
            }
        }

        func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            didFinish utterance: AVSpeechUtterance
        ) {
            guard let owner = owner else { return }

            Task { @MainActor in
                owner.currentSentenceIndex += 1
                if owner.currentSentenceIndex < owner.sentenceQueue.count {
                    owner.speakNextSentence()
                } else {
                    owner.isSpeaking = false
                    owner.onChapterComplete?()
                }
            }
        }

        func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            didCancel utterance: AVSpeechUtterance
        ) {
            Task { @MainActor in
                self.owner?.isSpeaking = false
            }
        }
    }
}
