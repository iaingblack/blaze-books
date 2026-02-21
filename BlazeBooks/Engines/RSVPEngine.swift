import Foundation

/// Timer-driven RSVP (Rapid Serial Visual Presentation) engine with ORP-aligned word advancement.
///
/// When TTS is off, RSVPEngine drives word display at the configured WPM with punctuation-aware
/// timing. It tokenizes chapter text via `WordTokenizer`, converts tokens to `ORPWord` values with
/// calculated ORP positions, and advances through them using a scheduled Timer.
///
/// **Timing model (from speedread open-source implementation):**
/// - Base interval: `60.0 / WPM` seconds per word
/// - Standard words: 0.9x multiplier (slightly faster than base)
/// - Length penalty: `+0.04 * sqrt(wordLength)` added to multiplier
/// - Clause punctuation (,;:): 2.0x multiplier
/// - Sentence-ending (.!?): 3.0x multiplier
///
/// **Resume behavior:** On resume after pause, backs up 4 words before the pause point
/// to help the reader regain context (per CONTEXT.md: 3-5 word range, using 4 as default).
@Observable
final class RSVPEngine {

    // MARK: - Observable State

    /// The current word being displayed, with ORP segments for alignment.
    var currentWord: ORPWord?
    /// Whether the engine is actively advancing through words.
    var isPlaying: Bool = false
    /// The current word index in the chapter's word array.
    var currentIndex: Int = 0
    /// Total number of words in the loaded chapter.
    var wordCount: Int = 0

    // MARK: - Private State

    @ObservationIgnored
    private var words: [ORPWord] = []
    @ObservationIgnored
    private var timer: Timer?
    @ObservationIgnored
    private var wpm: Int = 250
    @ObservationIgnored
    private let tokenizer = WordTokenizer()
    @ObservationIgnored
    private var punctuationPausesEnabled: Bool = true

    /// Called when the engine reaches the end of the chapter's word array.
    @ObservationIgnored
    var onChapterComplete: (() -> Void)?

    // MARK: - Chapter Loading

    /// Tokenizes chapter text and prepares the word array for RSVP display.
    ///
    /// Uses the existing `WordTokenizer` to split text into `WordToken` values,
    /// then converts each to an `ORPWord` with a calculated ORP position.
    /// Resets the current index to 0 and clears the playing state.
    ///
    /// - Parameter text: The full plain text of a chapter.
    func loadChapter(text: String) {
        let tokens = tokenizer.tokenize(text)
        words = tokens.map { ORPWord.from(token: $0) }
        wordCount = words.count
        currentIndex = 0
        currentWord = words.first
        isPlaying = false
        invalidateTimer()
    }

    // MARK: - Playback Controls

    /// Starts playing from the current index.
    func play() {
        guard !words.isEmpty else { return }
        isPlaying = true
        scheduleNextWord(delay: baseInterval)
    }

    /// Pauses playback. The last displayed word stays frozen on screen
    /// (per CONTEXT.md locked decision: frozen display on pause).
    func pause() {
        invalidateTimer()
        isPlaying = false
    }

    /// Resumes playback, backing up 4 words before the pause point to help
    /// the reader regain context (per CONTEXT.md: 3-5 word range).
    func resume() {
        guard !words.isEmpty else { return }
        let backupCount = 4
        currentIndex = max(0, currentIndex - backupCount)
        currentWord = words[currentIndex]
        isPlaying = true
        scheduleNextWord(delay: baseInterval)
    }

    /// Updates the WPM (words per minute), clamped to 100-500.
    /// If currently playing, recalculates the timer interval immediately.
    ///
    /// - Parameter newWPM: The desired words per minute.
    func setWPM(_ newWPM: Int) {
        wpm = max(100, min(500, newWPM))
        if isPlaying {
            // Reschedule with new timing
            invalidateTimer()
            scheduleNextWord(delay: baseInterval)
        }
    }

    /// Enables or disables punctuation-aware pauses (sentence-end and clause multipliers).
    ///
    /// When disabled, all words use the same base timing with only the length penalty.
    /// - Parameter enabled: Whether to apply punctuation pause multipliers.
    func setPunctuationPauses(_ enabled: Bool) {
        punctuationPausesEnabled = enabled
    }

    /// Seeks to a specific word index, updating the displayed word.
    ///
    /// - Parameter index: The target word index (clamped to valid range).
    func seekTo(index: Int) {
        guard !words.isEmpty else { return }
        currentIndex = max(0, min(index, words.count - 1))
        currentWord = words[currentIndex]
    }

    /// Returns the word at the given index, or nil if out of range.
    /// Used by ReadingCoordinator to look up words by TTS callback index.
    ///
    /// - Parameter index: The word index to look up.
    /// - Returns: The ORPWord at that index, or nil.
    func word(at index: Int) -> ORPWord? {
        guard index >= 0, index < words.count else { return nil }
        return words[index]
    }

    // MARK: - Private Timing

    /// Base interval in seconds for one word at the current WPM.
    private var baseInterval: TimeInterval {
        60.0 / Double(wpm)
    }

    /// Advances to the next word with punctuation-aware timing.
    ///
    /// Timing multipliers (from speedread open-source):
    /// - Standard word: 0.9x base interval
    /// - Length penalty: +0.04 * sqrt(wordLength)
    /// - Sentence-ending (.!?): 3.0x multiplier
    /// - Clause punctuation (,;:): 2.0x multiplier
    private func advanceToNextWord() {
        let nextIndex = currentIndex + 1

        // Check for chapter end
        guard nextIndex < words.count else {
            isPlaying = false
            invalidateTimer()
            onChapterComplete?()
            return
        }

        currentIndex = nextIndex
        let word = words[currentIndex]
        currentWord = word

        // Calculate delay for the NEXT word display
        let delay = displayDuration(for: word)
        scheduleNextWord(delay: delay)
    }

    /// Calculates the display duration for a word based on punctuation and length.
    ///
    /// - Parameter word: The ORPWord to calculate timing for.
    /// - Returns: The time interval this word should be displayed.
    private func displayDuration(for word: ORPWord) -> TimeInterval {
        var multiplier: Double = 0.9

        // Length penalty: longer words need more reading time
        multiplier += 0.04 * sqrt(Double(word.text.count))

        // Punctuation-aware pauses (skipped when pauses are disabled)
        if punctuationPausesEnabled {
            let lastChar = word.text.last ?? Character(" ")
            if ".!?".contains(lastChar) || word.isSentenceEnd {
                multiplier *= 3.0
            } else if ",;:".contains(lastChar) {
                multiplier *= 2.0
            }
        }

        return baseInterval * multiplier
    }

    /// Schedules a one-shot timer to fire `advanceToNextWord` after the given delay.
    /// Invalidates any existing timer before scheduling.
    ///
    /// - Parameter delay: The time interval before the next word advancement.
    private func scheduleNextWord(delay: TimeInterval) {
        invalidateTimer()
        timer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.advanceToNextWord()
        }
        // Ensure timer fires during scroll tracking and other UI interactions.
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Invalidates and nils out the current timer.
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}
