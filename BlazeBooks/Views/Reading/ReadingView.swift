import SwiftUI
import SwiftData

/// A scrollable reading view displaying book chapter text with position tracking.
///
/// Features:
/// - Readable typography (~17pt, comfortable line spacing)
/// - Chapter title as styled header
/// - Paragraph-based text layout with IDs for scroll restoration
/// - Auto-saving position on scroll (debounced)
/// - Position restoration on reopen
/// - Thin progress bar showing chapter/book progress
/// - Previous/next chapter navigation
/// - Broken chapter placeholder display
struct ReadingView: View {
    let book: Book

    @Environment(\.modelContext) private var modelContext
    @State private var positionService = ReadingPositionService()
    @State private var currentChapterIndex: Int = 0
    @State private var chapterText: String = ""
    @State private var chapterTitle: String = ""
    @State private var paragraphs: [IdentifiedParagraph] = []
    @State private var isLoading: Bool = true
    @State private var scrollTarget: String?
    @State private var isBrokenChapter: Bool = false

    private var sortedChapters: [Chapter] {
        (book.chapters ?? []).sorted { $0.index < $1.index }
    }

    private var totalChapters: Int {
        sortedChapters.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at the top
            progressBar

            if isLoading {
                ProgressView("Loading chapter...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Reading content
                ScrollViewReader { proxy in
                    ScrollView {
                        chapterContent
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetKey.self,
                                            value: geometry.frame(in: .named("scrollArea")).origin.y
                                        )
                                }
                            )
                    }
                    .coordinateSpace(name: "scrollArea")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        handleScrollChange(offset: offset)
                    }
                    .onChange(of: scrollTarget) { _, target in
                        if let target = target {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                            scrollTarget = nil
                        }
                    }
                }
            }

            // Chapter navigation bar at the bottom
            chapterNavigationBar
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadInitialPosition()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * positionService.overallProgress)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Chapter Content

    private var chapterContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // Chapter header
            Text(chapterTitle)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .id("chapter-header")

            if isBrokenChapter {
                brokenChapterPlaceholder
            } else {
                // Paragraphs
                ForEach(paragraphs) { paragraph in
                    Text(paragraph.text)
                        .font(.system(size: 17))
                        .lineSpacing(7)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                        .id(paragraph.id)
                }
            }

            // Bottom spacer for comfortable scrolling
            Spacer()
                .frame(height: 100)
                .id("chapter-end")
        }
    }

    // MARK: - Broken Chapter Placeholder

    private var brokenChapterPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("This chapter could not be displayed")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var chapterProgressText: String {
        guard totalChapters > 0 else { return "" }
        return "Chapter \(currentChapterIndex + 1) of \(totalChapters)"
    }

    // MARK: - Scroll Handling

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

    // MARK: - Navigation

    private func navigateChapter(direction: Int) {
        let newIndex = currentChapterIndex + direction
        guard newIndex >= 0, newIndex < totalChapters else { return }

        currentChapterIndex = newIndex
        loadChapter(at: newIndex)

        // Save position at new chapter start
        positionService.savePosition(
            book: book,
            chapterIndex: newIndex,
            scrollFraction: 0,
            chapterText: chapterText,
            modelContext: modelContext
        )
    }

    // MARK: - Loading

    private func loadInitialPosition() {
        positionService.loadPosition(for: book, modelContext: modelContext)
        currentChapterIndex = positionService.currentChapterIndex

        loadChapter(at: currentChapterIndex)

        // Restore scroll position after a brief delay to let layout settle
        if positionService.currentWordIndex > 0 && !paragraphs.isEmpty {
            let targetParagraphIndex = estimateParagraphFromWordIndex(
                wordIndex: positionService.currentWordIndex
            )
            if targetParagraphIndex < paragraphs.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollTarget = paragraphs[targetParagraphIndex].id
                }
            }
        }

        // Verify position using snippet
        verifyPosition()
    }

    private func loadChapter(at index: Int) {
        let chapters = sortedChapters
        guard index >= 0, index < chapters.count else {
            chapterTitle = "No Content"
            chapterText = ""
            paragraphs = []
            isBrokenChapter = true
            isLoading = false
            return
        }

        let chapter = chapters[index]
        chapterTitle = chapter.title
        chapterText = chapter.text

        // Check for broken chapter
        isBrokenChapter = chapter.wordCount == 0 ||
            chapter.text == "This chapter could not be displayed"

        if !isBrokenChapter {
            // Split text into paragraphs
            let rawParagraphs = chapter.text
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            paragraphs = rawParagraphs.enumerated().map { index, text in
                IdentifiedParagraph(id: "p-\(index)", text: text)
            }
        } else {
            paragraphs = []
        }

        // Reset scroll tracking for new chapter
        contentHeight = 1.0
        lastReportedOffset = 0.0
        isLoading = false
    }

    /// Estimates which paragraph contains the given word index.
    private func estimateParagraphFromWordIndex(wordIndex: Int) -> Int {
        guard !paragraphs.isEmpty else { return 0 }

        var cumulativeWords = 0
        for (index, paragraph) in paragraphs.enumerated() {
            let wordCount = paragraph.text.split(separator: " ").count
            cumulativeWords += wordCount
            if cumulativeWords >= wordIndex {
                return index
            }
        }

        return max(0, paragraphs.count - 1)
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
            print("[ReadingView] Position verification mismatch: snippet '\(position.verificationSnippet)' not found in chapter \(currentChapterIndex). Position may be approximate.")
        }
    }
}

// MARK: - Supporting Types

/// A paragraph with a stable ID for ScrollViewReader.
struct IdentifiedParagraph: Identifiable {
    let id: String
    let text: String
}

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
