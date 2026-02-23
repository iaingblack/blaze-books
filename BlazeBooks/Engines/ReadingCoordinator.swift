import Foundation

/// Central state machine orchestrating RSVP display and TTS speech with dual-mode operation.
///
/// ReadingCoordinator bridges the raw engines (RSVPEngine, TTSService) with the user-facing reading views.
/// It supports two reading modes (`.rsvp` and `.page`) with two drive modes each:
/// - **Timer mode (TTS off):** RSVPEngine drives word advancement at exact configured WPM
/// - **TTS mode (TTS on):** TTSService speech dictates word advancement; WPM is approximate
///
/// **Page mode specifics:**
/// - With TTS on: TTS drives word advancement via onWordBoundary callbacks (same as RSVP mode).
///   Page mode views observe `highlightedWordIndex` to show word highlighting.
/// - With TTS off: No timer drives word advancement. User reads at their own pace (passive scrolling).
///
/// **Key behaviors (locked decisions from CONTEXT.md):**
/// 1. TTS drives everything when active -- speech dictates word advancement, WPM becomes approximate
/// 2. Timer drives exact WPM when TTS is off
/// 3. On resume: back up ~4 words for context (within 3-5 range)
/// 4. Chapter auto-advance with brief pause at chapter boundaries
/// 5. Pause freezes last word on screen
/// 6. Slider snaps to actual capped WPM (shows reality)
/// 7. Mode switch preserves currentWordIndex across RSVP/page transitions (READ-03)
/// 8. setWPM updates engine state immediately; commitWPMChange() debounces TTS restart (NAV-01)
@Observable
final class ReadingCoordinator {

    // MARK: - Observable State (drives SwiftUI views)

    /// Current reading mode (page or RSVP). Defaults to RSVP since that's the existing behavior.
    var readingMode: ReadingMode = .rsvp
    /// The word currently displayed in the RSVP view.
    var currentWord: ORPWord?
    /// Whether reading is active (either Timer or TTS mode).
    var isPlaying: Bool = false
    /// True while TTS is starting up (cold-start delay before first word).
    var isTTSPreparing: Bool = false
    /// Whether playback has been active at least once since the chapter loaded.
    /// Used to keep the word highlight visible after pausing.
    var hasPlayedInChapter: Bool = false
    /// TTS toggle -- default OFF (silent RSVP is the primary mode, TTS is the enhancement).
    var isTTSEnabled: Bool = false
    /// User's requested WPM.
    var currentWPM: Int = 250
    /// Actual WPM after speed cap (may differ from currentWPM when voice is capped).
    var effectiveWPM: Int = 250
    /// Whether the current voice is capping the speed.
    var isSpeedCapped: Bool = false
    /// Inline banner message when speed is capped, e.g. "Voice capped at 320 WPM".
    var speedCapMessage: String = ""
    /// Whether punctuation pauses (sentence-end, comma, etc.) are applied.
    /// Persisted to UserDefaults so the preference survives app restarts.
    var punctuationPausesEnabled: Bool = true {
        didSet { UserDefaults.standard.set(punctuationPausesEnabled, forKey: "punctuationPausesEnabled") }
    }
    /// Current word index in the chapter's word array.
    var currentWordIndex: Int = 0
    /// Total number of words in the current chapter.
    var totalWordCount: Int = 0
    /// Index of the current chapter (zero-based).
    var currentChapterIndex: Int = 0

    /// The word index currently highlighted in page mode.
    ///
    /// Returns `currentWordIndex` when playing or when paused after playback has started,
    /// so the user can see their position. Returns `nil` before first play.
    var highlightedWordIndex: Int? {
        hasPlayedInChapter ? currentWordIndex : nil
    }

    // MARK: - Private State

    @ObservationIgnored
    private var rsvpEngine: RSVPEngine

    @ObservationIgnored
    private var ttsService: TTSService

    @ObservationIgnored
    private var speedCapService: SpeedCapService

    @ObservationIgnored
    private var chapterTexts: [String] = []

    @ObservationIgnored
    private var totalChapters: Int = 0

    /// Callback when auto-advance reaches a chapter whose text hasn't been extracted yet.
    /// ReadingView handles this by extracting the chapter on-demand and calling `updateChapterText`.
    @ObservationIgnored
    var onChapterNeedsExtraction: ((Int) -> Void)?

    /// Task handle for chapter auto-advance delay, allowing cancellation if user intervenes.
    @ObservationIgnored
    private var autoAdvanceTask: Task<Void, Never>?

    /// Observation token for RSVPEngine's currentWord changes in Timer mode.
    @ObservationIgnored
    private var rsvpObservation: (any Sendable)?

    // MARK: - Initialization

    /// Creates a ReadingCoordinator with the given speed cap service.
    ///
    /// RSVPEngine and TTSService are created internally. Callbacks are wired to
    /// coordinate dual-mode operation.
    ///
    /// - Parameter speedCapService: The service providing per-voice WPM capping.
    init(speedCapService: SpeedCapService) {
        self.speedCapService = speedCapService
        self.rsvpEngine = RSVPEngine()
        self.ttsService = TTSService()

        // Restore persisted punctuation pause preference
        if UserDefaults.standard.object(forKey: "punctuationPausesEnabled") != nil {
            let saved = UserDefaults.standard.bool(forKey: "punctuationPausesEnabled")
            self.punctuationPausesEnabled = saved
            rsvpEngine.setPunctuationPauses(saved)
            ttsService.setPunctuationPauses(saved)
        }

        // Wire chapter-complete callbacks
        rsvpEngine.onChapterComplete = { [weak self] in
            self?.handleChapterComplete()
        }
        ttsService.onWordBoundary = { [weak self] index in
            self?.handleTTSWordBoundary(index)
        }
        ttsService.onChapterComplete = { [weak self] in
            self?.handleChapterComplete()
        }
        ttsService.onError = { [weak self] in
            self?.handleTTSError()
        }
    }

    // MARK: - Public Methods

    /// Loads a book's chapter texts and positions to the specified chapter and word.
    ///
    /// Prepares both engines for the starting chapter and updates observable state
    /// (totalWordCount, totalChapters, currentChapterIndex).
    ///
    /// - Parameters:
    ///   - chapterTexts: Array of plain text for each chapter in the book.
    ///   - startChapter: The chapter index to begin at (zero-based).
    ///   - startWord: The word index within the chapter to start at.
    func loadBook(chapterTexts: [String], startChapter: Int, startWord: Int) {
        self.chapterTexts = chapterTexts
        self.totalChapters = chapterTexts.count

        guard startChapter < chapterTexts.count else { return }

        currentChapterIndex = startChapter
        let chapterText = chapterTexts[startChapter]

        // Load chapter into both engines
        rsvpEngine.loadChapter(text: chapterText)
        ttsService.prepareChapter(chapterText)

        // Seek to start word
        if startWord > 0 {
            rsvpEngine.seekTo(index: startWord)
        }

        totalWordCount = rsvpEngine.wordCount
        currentWordIndex = startWord
        currentWord = rsvpEngine.word(at: startWord)
        hasPlayedInChapter = false
    }

    /// Starts playback in the current mode (Timer or TTS).
    ///
    /// - **TTS on:** Starts speech from the current word index; TTS word-boundary callbacks
    ///   drive RSVP/page display updates.
    /// - **TTS off:** Starts RSVPEngine timer; subscribes to its currentWord changes.
    ///   In RSVP mode this drives the word display; in page mode it drives word highlighting.
    func play() {
        if isTTSEnabled {
            isTTSPreparing = true
            ttsService.speak(fromWordIndex: currentWordIndex)
        } else {
            // Timer drives word advancement (RSVP display or page mode highlighting)
            rsvpEngine.seekTo(index: currentWordIndex)
            rsvpEngine.play()
            startRSVPObservation()
        }
        isPlaying = true
        hasPlayedInChapter = true
    }

    /// Pauses playback in both engines. The current word stays frozen on screen
    /// (locked decision: pause freezes last word).
    func pause() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        rsvpEngine.pause()
        ttsService.pause()
        stopRSVPObservation()
        isPlaying = false
    }

    /// Resumes playback from the pause point.
    ///
    /// - **TTS on:** Uses `continueSpeaking()` to resume from the exact pause position.
    ///   AVSpeechSynthesizer tracks its own position internally, so destroying and recreating
    ///   the synthesizer is unnecessary and error-prone (the speak-from-word approach can only
    ///   restart from sentence boundaries, not mid-sentence).
    /// - **TTS off:** Backs up 4 words for context recovery (locked decision: 3-5 word range).
    func resume() {
        if isTTSEnabled {
            if ttsService.canResume {
                ttsService.resume()
            } else {
                // Synthesizer doesn't exist (e.g. cold start with restored position) —
                // fall back to creating a new one from the current word index.
                isTTSPreparing = true
                ttsService.speak(fromWordIndex: currentWordIndex)
            }
        } else {
            let backedUpIndex = max(0, currentWordIndex - 4)
            currentWordIndex = backedUpIndex
            currentWord = rsvpEngine.word(at: backedUpIndex)
            rsvpEngine.seekTo(index: backedUpIndex)
            rsvpEngine.play()
            startRSVPObservation()
        }
        isPlaying = true
        hasPlayedInChapter = true
    }

    /// Stops playback completely in both engines.
    func stop() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        rsvpEngine.pause()
        ttsService.stop()
        stopRSVPObservation()
        isPlaying = false
    }

    /// Sets the user's requested WPM, applying speed cap for the current voice.
    ///
    /// Called continuously during slider drag. Updates engine state immediately but does NOT
    /// restart TTS (avoids audio stuttering during slider drag per Research Pitfall 5).
    /// Call `commitWPMChange()` when the slider drag ends to restart TTS with the new rate.
    ///
    /// Clamps to 100-500 range. Queries SpeedCapService for effective WPM based on
    /// the current voice. Updates effectiveWPM, isSpeedCapped, speedCapMessage.
    /// Applies the effective WPM to the RSVPEngine timer immediately.
    ///
    /// Locked decision: slider snaps to actual capped WPM (shows reality).
    ///
    /// - Parameter wpm: The desired words per minute.
    func setWPM(_ wpm: Int) {
        currentWPM = max(100, min(500, wpm))
        applySpeedCap()

        // Apply effective WPM to RSVPEngine immediately (cheap, no restart needed)
        rsvpEngine.setWPM(effectiveWPM)
    }

    /// Commits a WPM change by restarting TTS from the current word index with the new rate.
    ///
    /// Called when the WPM slider drag ends (onEditingChanged = false). This is the debounce
    /// point that prevents audio stuttering during continuous slider drag (Research Pitfall 5).
    ///
    /// Only restarts TTS if it's currently enabled and playing. Silent RSVP mode doesn't need
    /// this -- RSVPEngine timer updates are applied immediately in `setWPM`.
    func commitWPMChange() {
        guard isTTSEnabled, isPlaying else { return }
        let resumeIndex = currentWordIndex
        ttsService.stop()
        if let voiceId = ttsService.currentVoiceIdentifier {
            ttsService.setRate(speedCapService.wpmToRate(effectiveWPM, forVoice: voiceId))
        }
        ttsService.speak(fromWordIndex: resumeIndex)
    }

    /// Switches between RSVP and page reading modes, preserving word position.
    ///
    /// Saves the current word index, stops both engines, sets the new mode, then restores
    /// the exact word position. If TTS was playing, resumes playback in the new mode.
    /// This ensures READ-03: position is preserved across mode switches.
    ///
    /// **Note:** When called from a SwiftUI Picker binding, `readingMode` may already
    /// be set to `newMode` (the Picker sets it before `onChange` fires). This method
    /// handles that gracefully by always performing the stop/restore/resume cycle.
    ///
    /// - Parameter newMode: The reading mode to switch to.
    func switchMode(to newMode: ReadingMode) {
        let savedIndex = currentWordIndex
        let wasTTSPlaying = isPlaying && isTTSEnabled

        // Stop current mode engines
        stop()

        // Set mode (may be redundant if Picker binding already set it, but safe)
        readingMode = newMode

        // Restore position
        currentWordIndex = savedIndex
        currentWord = rsvpEngine.word(at: savedIndex)

        // If TTS was playing, resume from same position in new mode
        if wasTTSPlaying {
            play()
        }
    }

    /// Toggles TTS mode. If currently playing, seamlessly switches between modes.
    ///
    /// - **Switching to TTS:** Stops RSVPEngine, starts TTSService from current word index.
    /// - **Switching from TTS:** Stops TTSService, seeks RSVPEngine to current word index, starts Timer.
    ///
    /// - Parameter enabled: Whether TTS should be active.
    func setTTSEnabled(_ enabled: Bool) {
        isTTSEnabled = enabled
        applySpeedCap()

        // Apply TTS rate so the next speak() uses the correct speed
        if enabled, let voiceId = ttsService.currentVoiceIdentifier {
            ttsService.setRate(speedCapService.wpmToRate(effectiveWPM, forVoice: voiceId))
        }

        if isPlaying {
            if enabled {
                // Switch from Timer to TTS
                rsvpEngine.pause()
                stopRSVPObservation()
                ttsService.speak(fromWordIndex: currentWordIndex)
            } else {
                // Switch from TTS to Timer
                ttsService.stop()
                rsvpEngine.seekTo(index: currentWordIndex)
                rsvpEngine.play()
                startRSVPObservation()
            }
        }
    }

    /// Toggles punctuation pauses on/off for both engines.
    ///
    /// When disabled, RSVP timer uses uniform word timing and TTS sends the chapter
    /// as a single utterance to minimize inter-sentence gaps.
    /// If TTS is currently playing, restarts speech with the new setting.
    ///
    /// - Parameter enabled: Whether punctuation pauses should be active.
    func setPunctuationPauses(_ enabled: Bool) {
        punctuationPausesEnabled = enabled
        rsvpEngine.setPunctuationPauses(enabled)
        ttsService.setPunctuationPauses(enabled)

        // Re-prepare TTS chapter with new chunking strategy
        if currentChapterIndex < chapterTexts.count {
            let resumeIndex = currentWordIndex
            let wasPlaying = isPlaying

            if isTTSEnabled && wasPlaying {
                ttsService.stop()
            }

            ttsService.prepareChapter(chapterTexts[currentChapterIndex])

            if isTTSEnabled && wasPlaying {
                ttsService.speak(fromWordIndex: resumeIndex)
            }
        }
    }

    /// Sets the TTS voice and recalculates speed cap for the new voice.
    /// If TTS is currently playing or paused, restarts speech with the new voice.
    ///
    /// - Parameter identifier: The AVSpeechSynthesisVoice identifier string.
    func setVoice(identifier: String) {
        ttsService.setVoice(identifier: identifier)
        applySpeedCap()

        // Re-apply rate for new voice
        ttsService.setRate(speedCapService.wpmToRate(effectiveWPM, forVoice: identifier))

        // Restart TTS if active — the old synthesizer's utterances have the previous voice baked in
        if isTTSEnabled && (isPlaying || ttsService.canResume) {
            let resumeIndex = currentWordIndex
            let wasPlaying = isPlaying
            ttsService.stop()
            ttsService.prepareChapter(chapterTexts[currentChapterIndex])
            if wasPlaying {
                ttsService.speak(fromWordIndex: resumeIndex)
            }
        }
    }

    /// Updates the cached chapter text at the given index.
    /// Called after background or on-demand extraction fills in a chapter's content.
    func updateChapterText(at index: Int, text: String) {
        guard index >= 0, index < chapterTexts.count else { return }
        chapterTexts[index] = text
    }

    // MARK: - Private Methods

    /// Handles unexpected TTS cancellation (voice error, system interruption).
    /// Resets playback state so the user isn't stuck with a "playing" UI but no audio.
    private func handleTTSError() {
        stopRSVPObservation()
        isPlaying = false
        isTTSPreparing = false
    }

    /// Handles TTS word-boundary callbacks by updating RSVP display.
    ///
    /// Locked decision: TTS drives everything when active -- speech dictates word advancement.
    /// The RSVP display word is looked up from RSVPEngine's word array to get proper ORP segments.
    ///
    /// - Parameter globalIndex: The global word index reported by TTSService.
    private func handleTTSWordBoundary(_ globalIndex: Int) {
        isTTSPreparing = false
        currentWordIndex = globalIndex
        currentWord = rsvpEngine.word(at: globalIndex)
    }

    /// Handles chapter completion from either engine. Auto-advances to the next chapter
    /// with a 1.5-second pause for the reader to process the chapter transition.
    ///
    /// Locked decision: chapter auto-advance with brief pause, then start next chapter automatically.
    private func handleChapterComplete() {
        let nextChapter = currentChapterIndex + 1

        guard nextChapter < totalChapters else {
            // Last chapter -- stop playback
            isPlaying = false
            stopRSVPObservation()
            return
        }

        // Auto-advance with 1.5-second pause (Claude's discretion for chapter transition duration)
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            } catch {
                return // Cancelled
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.loadNextChapter(nextChapter)
            }
        }
    }

    /// Loads and starts playing the next chapter.
    ///
    /// - Parameter chapterIndex: The index of the chapter to load.
    private func loadNextChapter(_ chapterIndex: Int) {
        guard chapterIndex < chapterTexts.count else { return }

        currentChapterIndex = chapterIndex
        let chapterText = chapterTexts[chapterIndex]

        // If chapter text hasn't been extracted yet, request extraction via callback.
        // The view will extract the chapter, call updateChapterText, and resume playback.
        if chapterText.isEmpty {
            isPlaying = false
            stopRSVPObservation()
            onChapterNeedsExtraction?(chapterIndex)
            return
        }

        rsvpEngine.loadChapter(text: chapterText)
        ttsService.prepareChapter(chapterText)

        totalWordCount = rsvpEngine.wordCount
        currentWordIndex = 0
        currentWord = rsvpEngine.word(at: 0)
        hasPlayedInChapter = false

        // Resume playback in the current mode
        play()
    }

    /// Queries SpeedCapService to determine effective WPM for the current voice/mode.
    ///
    /// When TTS is off, cap at slider max of 500 WPM (locked decision: silent RSVP capped at 500).
    /// When TTS is on, cap at the per-voice maximum.
    ///
    /// Locked decision: slider snaps to actual capped WPM; inline banner shows cap info.
    private func applySpeedCap() {
        if isTTSEnabled, let voiceId = ttsService.currentVoiceIdentifier {
            effectiveWPM = speedCapService.effectiveWPM(requested: currentWPM, forVoice: voiceId)
        } else {
            // Silent RSVP: cap at 500 (already enforced by setWPM clamp)
            effectiveWPM = currentWPM
        }

        if effectiveWPM < currentWPM {
            isSpeedCapped = true
            speedCapMessage = "Voice capped at \(effectiveWPM) WPM"
        } else {
            isSpeedCapped = false
            speedCapMessage = ""
        }
    }

    /// Starts observing RSVPEngine's word changes for Timer mode.
    ///
    /// Uses a polling approach via withObservationTracking to bridge RSVPEngine's
    /// @Observable state changes to the coordinator's state.
    private func startRSVPObservation() {
        observeRSVPChanges()
    }

    /// Recursively observes RSVPEngine state changes using withObservationTracking.
    private func observeRSVPChanges() {
        withObservationTracking {
            _ = self.rsvpEngine.currentWord
            _ = self.rsvpEngine.currentIndex
            _ = self.rsvpEngine.isPlaying
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.syncFromRSVPEngine()
                // Continue observing if still playing in Timer mode
                if self.isPlaying && !self.isTTSEnabled {
                    self.observeRSVPChanges()
                }
            }
        }
    }

    /// Syncs coordinator state from RSVPEngine (Timer mode).
    private func syncFromRSVPEngine() {
        currentWord = rsvpEngine.currentWord
        currentWordIndex = rsvpEngine.currentIndex

        // If RSVPEngine stopped itself (e.g., chapter end), update coordinator
        if !rsvpEngine.isPlaying && isPlaying && !isTTSEnabled {
            // Engine reached end -- chapter complete is handled by onChapterComplete callback
        }
    }

    /// Stops observing RSVPEngine changes.
    private func stopRSVPObservation() {
        // withObservationTracking stops naturally when we don't re-register
        // Setting a flag ensures observeRSVPChanges won't re-register
        rsvpObservation = nil
    }
}
