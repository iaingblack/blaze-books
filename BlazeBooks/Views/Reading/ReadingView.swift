import SwiftUI
import SwiftData

// MARK: - Reading Defaults

/// Shared constants for reading font size configuration.
/// Centralizes @AppStorage key and range to prevent inconsistent defaults across views.
enum ReadingDefaults {
    static let fontSizeKey = "readingFontSize"
    static let defaultFontSize: Double = 17.0
    static let minFontSize: Double = 12.0
    static let maxFontSize: Double = 32.0
    static let fontSizeStep: Double = 2.0

    static let rsvpFontSizeKey = "rsvpFontSize"
    static let rsvpDefaultFontSize: Double = 36.0
    static let rsvpMinFontSize: Double = 24.0
    static let rsvpMaxFontSize: Double = 56.0
    static let rsvpFontSizeStep: Double = 4.0
}

/// Dual-mode reading view supporting both scroll-based Page mode and RSVP speed reading.
///
/// Features:
/// - **Page mode:** Scrollable chapter text with word-level TTS highlighting via PageModeView
/// - **RSVP mode:** ORP-aligned single word display with optional TTS via RSVPDisplayView
/// - Mode toggle via segmented control in the toolbar (binds to coordinator.readingMode)
/// - Position-preserving mode switching via coordinator.switchMode(to:) (READ-03)
/// - Shared WPM slider (WPMSliderView) with debounced TTS restart (NAV-01)
/// - TTS controls available in both modes (play/pause, voice picker, speed cap banner)
/// - Readable typography (~17pt, comfortable line spacing) in Page mode
/// - Chapter title as styled header
/// - Auto-saving position on scroll (page mode) or word change (both modes with TTS)
/// - Position restoration on reopen
/// - Thin progress bar showing chapter/book progress
/// - Previous/next chapter navigation
/// - Broken chapter placeholder display
struct ReadingView: View {
    let book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(ReadingCoordinator.self) private var coordinator
    @Environment(VoiceManager.self) private var voiceManager
    @Environment(EPUBImportService.self) private var importService
    @State private var positionService = ReadingPositionService()
    @State private var parserService = EPUBParserService()
    @State private var currentChapterIndex: Int = 0
    @State private var chapterText: String = ""
    @State private var chapterTitle: String = ""
    @State private var isLoading: Bool = true
    @State private var isBrokenChapter: Bool = false

    // MARK: - Page Mode State

    /// Service for paragraph processing and word-level AttributedString highlighting.
    @State private var pageTextService = PageTextService()
    /// Pre-computed paragraphs with cached word tokens for page mode highlighting.
    @State private var pageParagraphs: [PageTextService.ParagraphData] = []
    /// Paragraph ID to scroll to on initial appear for position restoration.
    @State private var initialPageScrollTarget: String?

    // MARK: - Font Size State

    /// User-adjustable font size for page mode reading, persisted via UserDefaults.
    @AppStorage(ReadingDefaults.fontSizeKey) private var readingFontSize: Double = ReadingDefaults.defaultFontSize

    /// User-adjustable font size for RSVP mode, persisted separately via UserDefaults.
    @AppStorage(ReadingDefaults.rsvpFontSizeKey) private var rsvpFontSize: Double = ReadingDefaults.rsvpDefaultFontSize

    // MARK: - Table of Contents State

    /// Whether the table of contents sheet is presented.
    @State private var showTableOfContents = false

    // MARK: - Shared Controls State

    /// Whether the voice picker sheet is presented.
    @State private var showVoicePicker: Bool = false
    /// Whether the WPM slider is expanded/visible.
    @State private var showWPMSlider: Bool = false
    /// Local slider value for smooth dragging (synced to coordinator on change).
    @State private var sliderWPM: Double = 250
    /// Timer for debounced position saves during TTS/RSVP playback.
    @State private var positionSaveTask: Task<Void, Never>?

    private var sortedChapters: [Chapter] {
        (book.chapters ?? []).sorted { $0.index < $1.index }
    }

    private var totalChapters: Int {
        sortedChapters.count
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(spacing: 0) {
            // Progress bar at the top
            progressBar

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(loadingStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if coordinator.readingMode == .rsvp {
                rsvpModeContent
            } else {
                pageModeContentView
            }

            // Chapter navigation bar at the bottom (both modes)
            chapterNavigationBar
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showTableOfContents = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
            ToolbarItem(placement: .principal) {
                modeToggle
            }
            ToolbarItem(placement: .topBarTrailing) {
                fontSizeControls
            }
        }
        .task {
            // Yield to allow the loading spinner to render before heavy work
            await Task.yield()
            loadInitialPosition()
            sliderWPM = Double(coordinator.currentWPM)
            // Apply persisted voice so TTS uses the user's chosen voice from the start
            if let voice = voiceManager.selectedVoice {
                coordinator.setVoice(identifier: voice.identifier)
            }
        }
        .onDisappear {
            // Stop playback when leaving the reading view
            coordinator.stop()
            positionSaveTask?.cancel()
        }
        .onChange(of: coordinator.currentChapterIndex) { _, newChapter in
            // Coordinator reports chapter change (auto-advance or needs-extraction)
            if newChapter != currentChapterIndex {
                let wasPlaying = coordinator.isPlaying
                currentChapterIndex = newChapter

                let chapters = sortedChapters
                if newChapter < chapters.count && chapters[newChapter].text.isEmpty {
                    // Chapter needs extraction — load will extract async, then resume
                    isLoading = true
                    Task {
                        await extractChapterOnDemand(
                            chapter: chapters[newChapter],
                            index: newChapter,
                            resumePlayback: wasPlaying || !coordinator.isPlaying
                        )
                    }
                } else {
                    loadChapter(at: newChapter)
                }
            }
        }
        .onChange(of: coordinator.currentWordIndex) { _, _ in
            // Debounced position save when playback is active (both modes with TTS or RSVP timer)
            if coordinator.isPlaying {
                savePlaybackPositionDebounced()
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            VoicePickerView(
                voiceManager: voiceManager,
                onVoiceSelected: { voice in
                    coordinator.setVoice(identifier: voice.identifier)
                    showVoicePicker = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTableOfContents) {
            TableOfContentsView(
                chapters: sortedChapters,
                currentChapterIndex: currentChapterIndex,
                onChapterSelected: { chapterIndex in
                    showTableOfContents = false
                    jumpToChapter(chapterIndex)
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        @Bindable var coordinator = coordinator
        return Picker("Mode", selection: $coordinator.readingMode) {
            ForEach(ReadingMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
        .onChange(of: coordinator.readingMode) { oldMode, newMode in
            // switchMode preserves word index and optionally resumes TTS (READ-03)
            coordinator.switchMode(to: newMode)

            // When switching to page mode, ensure pageParagraphs are computed
            if newMode == .page {
                pageParagraphs = pageTextService.splitIntoParagraphs(
                    text: chapterText, chapterIndex: currentChapterIndex
                )
            }
        }
    }

    // MARK: - Font Size Controls

    /// Inline font size adjustment controls (A-/pt/A+).
    /// Adjusts the appropriate font size based on current reading mode.
    private var fontSizeControls: some View {
        let isRSVP = coordinator.readingMode == .rsvp
        let currentSize = isRSVP ? rsvpFontSize : readingFontSize
        let minSize = isRSVP ? ReadingDefaults.rsvpMinFontSize : ReadingDefaults.minFontSize
        let maxSize = isRSVP ? ReadingDefaults.rsvpMaxFontSize : ReadingDefaults.maxFontSize
        let step = isRSVP ? ReadingDefaults.rsvpFontSizeStep : ReadingDefaults.fontSizeStep

        return HStack(spacing: 6) {
            Button {
                if isRSVP {
                    rsvpFontSize = max(minSize, rsvpFontSize - step)
                } else {
                    readingFontSize = max(minSize, readingFontSize - step)
                }
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.title3)
            }
            .disabled(currentSize <= minSize)

            Text("\(Int(currentSize))pt")
                .font(.system(.caption, design: .rounded).monospacedDigit())
                .frame(width: 45)

            Button {
                if isRSVP {
                    rsvpFontSize = min(maxSize, rsvpFontSize + step)
                } else {
                    readingFontSize = min(maxSize, readingFontSize + step)
                }
            } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.title3)
            }
            .disabled(currentSize >= maxSize)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))

                if coordinator.readingMode == .rsvp || coordinator.isPlaying {
                    // Word-level progress when in RSVP mode or when TTS is active in page mode
                    let wordProgress = coordinator.totalWordCount > 0
                        ? Double(coordinator.currentWordIndex) / Double(coordinator.totalWordCount)
                        : 0.0
                    let chapterWeight = totalChapters > 0 ? 1.0 / Double(totalChapters) : 1.0
                    let overall = (Double(currentChapterIndex) * chapterWeight) + (wordProgress * chapterWeight)

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * max(0, min(1, overall)))
                } else {
                    // Scroll-based progress in page mode without TTS
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * positionService.overallProgress)
                }
            }
        }
        .frame(height: 3)
    }

    // MARK: - RSVP Mode Content

    private var rsvpModeContent: some View {
        VStack(spacing: 0) {
            // Speed cap banner (conditionally visible)
            SpeedCapBanner(
                message: coordinator.speedCapMessage,
                isVisible: coordinator.isSpeedCapped
            )
            .animation(.easeInOut(duration: 0.3), value: coordinator.isSpeedCapped)

            Spacer()

            // RSVP Display at center
            ZStack {
                RSVPDisplayView(word: coordinator.currentWord, fontSize: rsvpFontSize)
                    .padding(.horizontal, 16)

                // Play button overlay when paused (locked decision: pause freezes last word with play overlay)
                if !coordinator.isPlaying && coordinator.currentWord != nil {
                    Button {
                        coordinator.resume()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                }
            }

            // Word progress text
            Text(wordProgressText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            // WPM Slider (expandable)
            if showWPMSlider {
                wpmSlider
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Controls bar at bottom
            readingControlsBar
        }
    }

    // MARK: - Page Mode Content (with PageModeView)

    private var pageModeContentView: some View {
        VStack(spacing: 0) {
            // Speed cap banner (self-hides when isSpeedCapped is false)
            SpeedCapBanner(
                message: coordinator.speedCapMessage,
                isVisible: coordinator.isSpeedCapped
            )
            .animation(.easeInOut(duration: 0.3), value: coordinator.isSpeedCapped)

            // PageModeView handles highlighting, auto-scroll, and broken chapter placeholder
            PageModeView(
                paragraphs: isBrokenChapter ? [] : pageParagraphs,
                highlightedWordIndex: coordinator.highlightedWordIndex,
                chapterTitle: chapterTitle,
                pageTextService: pageTextService,
                readingFontSize: readingFontSize,
                onScrollOffsetChange: { offset in
                    handleScrollChange(offset: offset)
                },
                initialScrollTarget: initialPageScrollTarget
            )

            // WPM Slider (expandable)
            if showWPMSlider {
                wpmSlider
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Controls bar at bottom (play/pause, TTS toggle, voice picker, WPM)
            readingControlsBar
        }
    }

    // MARK: - Reading Controls Bar (shared between modes)

    /// Controls bar with TTS toggle, voice picker, play/pause, and WPM display.
    /// Used in both RSVP and page modes.
    private var readingControlsBar: some View {
        HStack(spacing: 20) {
            // Voice controls group (tighter spacing)
            HStack(spacing: 8) {
                // TTS toggle
                Button {
                    if !coordinator.isTTSEnabled {
                        // Ensure voice is set before enabling TTS to avoid silent failures
                        if let voice = voiceManager.selectedVoice {
                            coordinator.setVoice(identifier: voice.identifier)
                        }
                    }
                    coordinator.setTTSEnabled(!coordinator.isTTSEnabled)
                } label: {
                    Image(systemName: coordinator.isTTSEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.title3)
                        .foregroundStyle(coordinator.isTTSEnabled ? Color.accentColor : .secondary)
                        .frame(width: 44, height: 44)
                }

                // Voice picker button (only enabled when TTS is on)
                Button {
                    showVoicePicker = true
                } label: {
                    Image(systemName: "person.wave.2")
                        .font(.title3)
                        .foregroundStyle(coordinator.isTTSEnabled ? Color.primary : Color.secondary.opacity(0.5))
                        .frame(width: 44, height: 44)
                }
                .disabled(!coordinator.isTTSEnabled)

                // Punctuation pauses toggle
                Button {
                    coordinator.setPunctuationPauses(!coordinator.punctuationPausesEnabled)
                } label: {
                    Image(systemName: coordinator.punctuationPausesEnabled ? "ellipsis.circle.fill" : "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(coordinator.punctuationPausesEnabled ? Color.accentColor : .secondary)
                        .frame(width: 44, height: 44)
                }
            }

            Spacer()

            // Play/Pause button (large, central)
            Button {
                if coordinator.isPlaying {
                    coordinator.pause()
                } else if coordinator.currentWordIndex > 0 {
                    coordinator.resume()
                } else {
                    coordinator.play()
                }
            } label: {
                if coordinator.isTTSPreparing {
                    ProgressView()
                        .frame(width: 50, height: 50)
                } else {
                    Image(systemName: coordinator.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .disabled(coordinator.isTTSPreparing)

            Spacer()

            // WPM display / slider toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showWPMSlider.toggle()
                }
            } label: {
                Text("\(coordinator.effectiveWPM)")
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("wpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70, height: 44)

            // Placeholder for layout balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - WPM Slider (shared component)

    private var wpmSlider: some View {
        WPMSliderView(
            sliderWPM: $sliderWPM,
            effectiveWPM: coordinator.effectiveWPM,
            isSpeedCapped: coordinator.isSpeedCapped,
            onWPMChanged: { wpm in coordinator.setWPM(wpm) },
            onWPMChangeEnded: { _ in coordinator.commitWPMChange() }
        )
    }

    // MARK: - Word Progress Text

    private var wordProgressText: String {
        guard coordinator.totalWordCount > 0 else { return "" }
        return "Word \(coordinator.currentWordIndex + 1) of \(coordinator.totalWordCount)"
    }

    /// Dynamic loading status: shows extraction progress if the import service
    /// is actively extracting this book's chapters, otherwise a generic message.
    private var loadingStatusText: String {
        if let progress = importService.extractionProgress[book.fileHash],
           progress.totalChapters > 0 {
            let pct = Int(Double(progress.completedChapters) / Double(progress.totalChapters) * 100)
            return "Extracting chapters\u{2026} \(pct)%"
        }
        return "Preparing chapter\u{2026}"
    }

    // MARK: - Chapter Navigation Bar

    private var chapterNavigationBar: some View {
        HStack {
            Button {
                navigateChapter(direction: -1)
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .font(.subheadline)
            }
            .disabled(currentChapterIndex <= 0)

            Spacer()

            Text(chapterProgressText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                navigateChapter(direction: 1)
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.trailingIcon)
                    .font(.subheadline)
            }
            .disabled(currentChapterIndex >= totalChapters - 1)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var chapterProgressText: String {
        guard totalChapters > 0 else { return "" }
        return "Chapter \(currentChapterIndex + 1) of \(totalChapters)"
    }

    // MARK: - Scroll Handling (page mode)

    @State private var contentHeight: CGFloat = 1.0
    @State private var lastReportedOffset: CGFloat = 0.0

    private func handleScrollChange(offset: CGFloat) {
        // offset is typically negative as user scrolls down
        let scrolled = -offset
        // Estimate total content height from how far we can scroll
        // We use a simple approximation: track the maximum scroll offset seen
        if scrolled > contentHeight {
            contentHeight = scrolled
        }

        guard contentHeight > 0 else { return }
        let fraction = max(0, min(1, scrolled / max(contentHeight, 1)))

        // Only save if the scroll position changed meaningfully
        guard abs(scrolled - lastReportedOffset) > 20 else { return }
        lastReportedOffset = scrolled

        positionService.updateProgress(
            scrollFraction: fraction,
            chapterIndex: currentChapterIndex,
            totalChapters: totalChapters
        )

        positionService.savePosition(
            book: book,
            chapterIndex: currentChapterIndex,
            scrollFraction: fraction,
            chapterText: chapterText,
            modelContext: modelContext
        )
    }

    // MARK: - Playback Position Saving

    /// Debounced position save for TTS/RSVP playback (2-second interval matches ReadingPositionService).
    /// Used in both RSVP mode and page mode with TTS active.
    private func savePlaybackPositionDebounced() {
        positionSaveTask?.cancel()
        positionSaveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            let wordIndex = coordinator.currentWordIndex
            let chapterIdx = coordinator.currentChapterIndex
            let wordProgress = coordinator.totalWordCount > 0
                ? Double(wordIndex) / Double(coordinator.totalWordCount)
                : 0.0

            positionService.updateProgress(
                scrollFraction: wordProgress,
                chapterIndex: chapterIdx,
                totalChapters: totalChapters
            )

            positionService.savePosition(
                book: book,
                chapterIndex: chapterIdx,
                scrollFraction: wordProgress,
                chapterText: chapterText,
                modelContext: modelContext
            )
        }
    }

    // MARK: - Navigation

    private func navigateChapter(direction: Int) {
        jumpToChapter(currentChapterIndex + direction)
    }

    /// Jumps to a specific chapter by index. Stops any active playback, loads
    /// the chapter content, reloads the coordinator, and saves the new position.
    /// Used by both prev/next navigation and table of contents selection.
    private func jumpToChapter(_ newIndex: Int) {
        guard newIndex >= 0, newIndex < totalChapters else { return }

        // Stop playback if active
        coordinator.stop()

        currentChapterIndex = newIndex

        let chapters = sortedChapters
        let chapter = chapters[newIndex]

        // If chapter needs extraction, loadChapter will handle async extraction
        // and we reload the coordinator after content is available
        if chapter.text.isEmpty {
            loadChapter(at: newIndex)
            // After on-demand extraction completes (async), the coordinator
            // will be updated via extractChapterOnDemand → updateChapterText
            Task {
                // Wait for extraction to finish (isLoading becomes false)
                while isLoading {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms poll
                }
                let chapterTexts = sortedChapters.map(\.text)
                coordinator.loadBook(
                    chapterTexts: chapterTexts,
                    startChapter: newIndex,
                    startWord: 0
                )
                positionService.savePosition(
                    book: book,
                    chapterIndex: newIndex,
                    scrollFraction: 0,
                    chapterText: chapterText,
                    modelContext: modelContext
                )
            }
        } else {
            loadChapter(at: newIndex)
            let chapterTexts = sortedChapters.map(\.text)
            coordinator.loadBook(
                chapterTexts: chapterTexts,
                startChapter: newIndex,
                startWord: 0
            )
            positionService.savePosition(
                book: book,
                chapterIndex: newIndex,
                scrollFraction: 0,
                chapterText: chapterText,
                modelContext: modelContext
            )
        }
    }

    // MARK: - Loading

    private func loadInitialPosition() {
        positionService.loadPosition(for: book, modelContext: modelContext)
        currentChapterIndex = positionService.currentChapterIndex

        let chapters = sortedChapters
        let startChapter = currentChapterIndex

        // If the starting chapter hasn't been extracted yet, extract it first
        if startChapter < chapters.count && chapters[startChapter].text.isEmpty {
            isLoading = true
            Task {
                await extractChapterOnDemand(chapter: chapters[startChapter], index: startChapter)
                finishInitialLoad(startWord: positionService.currentWordIndex)
            }
            return
        }

        loadChapter(at: currentChapterIndex)
        finishInitialLoad(startWord: positionService.currentWordIndex)
    }

    /// Completes initial loading after the starting chapter's text is available.
    private func finishInitialLoad(startWord: Int) {
        let chapterTexts = sortedChapters.map(\.text)
        coordinator.loadBook(
            chapterTexts: chapterTexts,
            startChapter: currentChapterIndex,
            startWord: startWord
        )

        // Wire auto-advance extraction callback.
        // When auto-advance encounters an un-extracted chapter, the coordinator pauses
        // and sets currentChapterIndex (triggering the view's onChange → loadChapter).
        // loadChapter handles extraction and the view is updated. But we also need to
        // resume playback, which the onChange handler doesn't do. So we use the callback.
        wireChapterExtractionCallback()

        // Set initial scroll target for PageModeView position restoration
        if startWord > 0 && !pageParagraphs.isEmpty {
            if let pIdx = pageTextService.paragraphIndex(
                forWordIndex: startWord,
                paragraphs: pageParagraphs
            ) {
                initialPageScrollTarget = pageParagraphs[pIdx].id
            }
        }

        // Verify position using snippet
        verifyPosition()
    }

    /// Wires the coordinator's onChapterNeedsExtraction callback for auto-advance.
    /// When auto-advance hits an un-extracted chapter, the coordinator pauses and calls this.
    /// Uses the same wait-then-fallback pattern as extractChapterOnDemand to avoid
    /// redundant openEPUB calls when the import's background extraction is running.
    private func wireChapterExtractionCallback() {
        let book = self.book
        let parserService = self.parserService
        let importService = self.importService

        coordinator.onChapterNeedsExtraction = { chapterIndex in
            Task { @MainActor in
                let chapters = (book.chapters ?? []).sorted { $0.index < $1.index }
                guard chapterIndex < chapters.count else { return }
                let chapter = chapters[chapterIndex]
                guard chapter.text.isEmpty else { return }

                // Wait for background extraction if running
                if let progress = importService.extractionProgress[book.fileHash],
                   !progress.isComplete {
                    for _ in 0..<20 {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if !chapter.text.isEmpty { break }
                    }
                }

                // If background filled it, done
                if !chapter.text.isEmpty { return }

                // Fallback: extract directly
                let filePath = book.filePath
                guard !filePath.isEmpty else { return }
                let booksDir = FileStorageManager.booksDirectory
                let fileURL = booksDir.appendingPathComponent(filePath)

                do {
                    let publication = try await parserService.openEPUB(at: fileURL)
                    let parsed = await parserService.extractSingleChapter(from: publication, at: chapterIndex)
                    chapter.text = parsed.text
                    chapter.wordCount = parsed.wordCount
                } catch {
                    return
                }
            }
        }
    }

    private func loadChapter(at index: Int) {
        let chapters = sortedChapters
        guard index >= 0, index < chapters.count else {
            chapterTitle = "No Content"
            chapterText = ""
            pageParagraphs = []
            isBrokenChapter = true
            isLoading = false
            return
        }

        let chapter = chapters[index]
        chapterTitle = chapter.title

        // If chapter text hasn't been extracted yet, extract on-demand
        if chapter.text.isEmpty {
            isLoading = true
            Task {
                await extractChapterOnDemand(chapter: chapter, index: index)
            }
            return
        }

        applyChapterContent(chapter: chapter, index: index)
    }

    /// Extracts a single chapter's text on-demand when it hasn't been background-extracted yet.
    ///
    /// Uses a wait-then-fallback strategy: if the import service's background extraction is
    /// actively running for this book, polls briefly (up to 2s) for the background task to
    /// fill this chapter — avoiding a redundant `openEPUB` call. Falls back to direct
    /// extraction if the background task doesn't reach this chapter in time, or if no
    /// background extraction is running (e.g. CloudKit sync books).
    ///
    /// If `resumePlayback` is true, reloads the coordinator and resumes after extraction.
    private func extractChapterOnDemand(chapter: Chapter, index: Int, resumePlayback: Bool = false) async {
        // Wait for import's background extraction if it's actively running
        if let progress = importService.extractionProgress[book.fileHash],
           !progress.isComplete {
            // Poll for up to 2 seconds — background extraction processes ~5-10 chapters/sec
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if !chapter.text.isEmpty { break }
            }
        }

        // If background filled it, use it directly
        if !chapter.text.isEmpty {
            coordinator.updateChapterText(at: index, text: chapter.text)
            applyChapterContent(chapter: chapter, index: index)
            if resumePlayback {
                let chapterTexts = sortedChapters.map(\.text)
                coordinator.loadBook(chapterTexts: chapterTexts, startChapter: index, startWord: 0)
                coordinator.play()
            }
            return
        }

        // Fallback: extract ourselves (no background running, or it hasn't reached us)
        let filePath = book.filePath
        guard !filePath.isEmpty else {
            isBrokenChapter = true
            isLoading = false
            return
        }

        let booksDir = FileStorageManager.booksDirectory
        let fileURL = booksDir.appendingPathComponent(filePath)

        do {
            let publication = try await parserService.openEPUB(at: fileURL)
            let parsed = await parserService.extractSingleChapter(from: publication, at: index)

            chapter.text = parsed.text
            chapter.wordCount = parsed.wordCount

            coordinator.updateChapterText(at: index, text: parsed.text)
            applyChapterContent(chapter: chapter, index: index)

            if resumePlayback {
                let chapterTexts = sortedChapters.map(\.text)
                coordinator.loadBook(chapterTexts: chapterTexts, startChapter: index, startWord: 0)
                coordinator.play()
            }
        } catch {
            isBrokenChapter = true
            isLoading = false
        }
    }

    /// Applies chapter content to view state after text is available.
    private func applyChapterContent(chapter: Chapter, index: Int) {
        chapterText = chapter.text

        // Check for broken chapter: wordCount==0 with non-empty text means parse error
        isBrokenChapter = (chapter.wordCount == 0 && !chapter.text.isEmpty) ||
            chapter.text == "This chapter could not be displayed"

        if !isBrokenChapter {
            pageParagraphs = pageTextService.splitIntoParagraphs(
                text: chapter.text, chapterIndex: index
            )
        } else {
            pageParagraphs = []
        }

        // Reset scroll tracking for new chapter
        contentHeight = 1.0
        lastReportedOffset = 0.0
        initialPageScrollTarget = nil
        isLoading = false
    }

    /// Verifies the restored position using the verification snippet.
    private func verifyPosition() {
        guard let position = book.readingPosition,
              !position.verificationSnippet.isEmpty else {
            return
        }

        // Simple verification: check if snippet exists in the current chapter text
        if !chapterText.isEmpty && !chapterText.contains(position.verificationSnippet) {
            // Log a warning -- full search-nearby logic deferred to later phases
            #if DEBUG
            print("[ReadingView] Position verification mismatch: snippet '\(position.verificationSnippet)' not found in chapter \(currentChapterIndex). Position may be approximate.")
            #endif
        }
    }
}

// MARK: - Supporting Types

/// A trailing icon label style for the "Next" button.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
