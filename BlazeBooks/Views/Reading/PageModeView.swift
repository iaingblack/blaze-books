import SwiftUI

/// Scrollable page mode reading view with word-level highlighting and auto-scroll.
///
/// Renders chapter text as paragraphs in a `LazyVStack` within a `ScrollViewReader`.
/// When playback is active (TTS or timer), the currently spoken/paced word is highlighted
/// with a yellow background via `PageTextService.attributedString(for:highlightedWordIndex:)`.
/// The view auto-scrolls to keep the paragraph containing the highlighted word centered on screen.
///
/// **Design decisions:**
/// - Uses `LazyVStack` for memory-efficient paragraph rendering (chapters may have 200+ paragraphs)
/// - `ScrollViewReader` + `.onChange(of: highlightedWordIndex)` for auto-scroll to active paragraph
/// - `.transaction { $0.animation = nil }` suppresses SwiftUI animation on highlight changes
///   (Research anti-pattern: animation at TTS speed causes visual lag behind speech)
/// - Tracks `lastScrolledParagraph` to avoid redundant scroll animations when highlight
///   moves within the same paragraph
/// - Empty paragraphs array shows a broken chapter placeholder (same as ReadingView)
/// - Supports scroll offset tracking for manual reading position saves
/// - Supports initial scroll target for position restoration on reopen
struct PageModeView: View {

    /// Paragraph data from `PageTextService.splitIntoParagraphs`.
    let paragraphs: [PageTextService.ParagraphData]

    /// Global word index to highlight, driven by `ReadingCoordinator.highlightedWordIndex`.
    /// Nil when paused (no frozen highlight per Research recommendation).
    let highlightedWordIndex: Int?

    /// Chapter heading text.
    let chapterTitle: String

    /// Service instance for generating `AttributedString` with word highlighting.
    let pageTextService: PageTextService

    /// User-adjustable font size for paragraph text, passed from ReadingView's @AppStorage.
    let readingFontSize: Double

    /// Callback for scroll offset changes during manual reading (for position saving).
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil

    /// Paragraph ID to scroll to on initial appear (for position restoration).
    var initialScrollTarget: String? = nil

    /// Tracks the last paragraph we auto-scrolled to, preventing redundant scroll
    /// animations when the highlight moves between words within the same paragraph.
    @State private var lastScrolledParagraph: Int = -1

    var body: some View {
        if paragraphs.isEmpty {
            brokenChapterPlaceholder
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Chapter header (consistent style with ReadingView)
                        Text(chapterTitle)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.horizontal, 28)
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                            .id("chapter-header")

                        // Paragraphs with word highlighting
                        ForEach(paragraphs) { paragraph in
                            Text(pageTextService.attributedString(
                                for: paragraph,
                                highlightedWordIndex: highlightedWordIndex
                            ))
                            .font(.system(size: readingFontSize))
                            .lineSpacing(readingFontSize * 0.41)
                            .textSelection(.enabled)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 14)
                            .id(paragraph.id)
                            .transaction { $0.animation = nil } // No animation on highlight swap (Research anti-pattern)
                        }

                        Spacer().frame(height: 100)
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: geometry.frame(in: .named("pageScrollArea")).origin.y
                                )
                        }
                    )
                }
                .coordinateSpace(name: "pageScrollArea")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    onScrollOffsetChange?(offset)
                }
                .onChange(of: highlightedWordIndex) { _, newIndex in
                    // Auto-scroll to paragraph containing highlighted word
                    guard let newIndex = newIndex else { return }
                    if let pIdx = pageTextService.paragraphIndex(forWordIndex: newIndex, paragraphs: paragraphs),
                       pIdx != lastScrolledParagraph {
                        lastScrolledParagraph = pIdx
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(paragraphs[pIdx].id, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    if let idx = highlightedWordIndex,
                       let pIdx = pageTextService.paragraphIndex(forWordIndex: idx, paragraphs: paragraphs) {
                        // Playback active on appear — scroll to highlighted word's paragraph
                        lastScrolledParagraph = pIdx
                        proxy.scrollTo(paragraphs[pIdx].id, anchor: .center)
                    } else if let target = initialScrollTarget {
                        // No playback — restore manual reading position
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                        }
                    }
                }
            }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20)
    }
}
