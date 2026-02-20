import Foundation
import SwiftUI

/// Stateless service for paragraph-level text processing with word highlighting support.
///
/// PageTextService splits chapter text into paragraphs, pre-computes word ranges for
/// O(1) word-to-paragraph lookup, and generates `AttributedString` values with word-level
/// background color highlighting for the page mode reading view.
///
/// **Design decisions:**
/// - Struct (not @Observable) -- stateless service like `WordTokenizer`
/// - Uses `WordTokenizer` for all tokenization (consistency with RSVPEngine/TTSService)
/// - Caches tokenized words per paragraph at split time (avoids re-tokenization per
///   word highlight change, per Research Pitfall 1)
/// - `AttributedString` with `.backgroundColor` for highlighting (not per-word Text views)
struct PageTextService {

    private let tokenizer = WordTokenizer()

    // MARK: - Paragraph Data Model

    /// A single paragraph of chapter text with pre-computed word range and cached tokens.
    ///
    /// Used by `PageModeView` to render paragraphs as `Text(AttributedString)` in a `LazyVStack`.
    /// The `wordRange` enables O(1) lookup of which paragraph contains a given global word index.
    struct ParagraphData: Identifiable {
        /// Stable paragraph ID in the form "ch{chapterIndex}-p{paragraphIndex}" (e.g., "ch0-p3").
        let id: String
        /// Raw paragraph text.
        let text: String
        /// Global word indices this paragraph covers (half-open range, e.g., 45..<78).
        /// `lowerBound` is the first word's global index; `upperBound` is `lowerBound + cachedTokens.count`.
        let wordRange: Range<Int>
        /// Pre-tokenized words for this paragraph, cached at chapter load time.
        /// Avoids re-tokenization on every word highlight change (Research Pitfall 1).
        let cachedTokens: [WordToken]
    }

    // MARK: - Paragraph Splitting

    /// Splits chapter text into paragraphs with pre-computed word ranges and cached tokens.
    ///
    /// Normalizes line endings, splits on double newlines (or single newlines if no double
    /// newlines are present), trims whitespace, and filters empty paragraphs. Each paragraph
    /// is tokenized with `WordTokenizer` to compute its global word range and cache tokens.
    ///
    /// - Parameters:
    ///   - text: The full plain text of a chapter.
    ///   - chapterIndex: The zero-based chapter index, used for stable paragraph IDs.
    /// - Returns: Array of `ParagraphData` with contiguous word ranges covering all words.
    func splitIntoParagraphs(text: String, chapterIndex: Int) -> [ParagraphData] {
        // Normalize line endings
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")

        // Split on \n\n if present, else split on \n
        let rawParagraphs: [String]
        if normalized.contains("\n\n") {
            rawParagraphs = normalized.components(separatedBy: "\n\n")
        } else {
            rawParagraphs = normalized.components(separatedBy: "\n")
        }

        // Trim whitespace and filter empty
        let trimmed = rawParagraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var paragraphs: [ParagraphData] = []
        var cumulativeWordCount = 0

        for (index, paragraphText) in trimmed.enumerated() {
            let tokens = tokenizer.tokenize(paragraphText)
            let wordRange = cumulativeWordCount..<(cumulativeWordCount + tokens.count)

            paragraphs.append(ParagraphData(
                id: "ch\(chapterIndex)-p\(index)",
                text: paragraphText,
                wordRange: wordRange,
                cachedTokens: tokens
            ))

            cumulativeWordCount += tokens.count
        }

        return paragraphs
    }

    // MARK: - Word-to-Paragraph Lookup

    /// Returns the index of the paragraph containing the given global word index.
    ///
    /// Simple linear scan is sufficient for typical chapter sizes (50-200 paragraphs).
    ///
    /// - Parameters:
    ///   - wordIndex: The global word index to look up.
    ///   - paragraphs: The paragraph array from `splitIntoParagraphs`.
    /// - Returns: The paragraph index, or nil if the word index is out of range.
    func paragraphIndex(forWordIndex wordIndex: Int, paragraphs: [ParagraphData]) -> Int? {
        paragraphs.firstIndex { $0.wordRange.contains(wordIndex) }
    }

    // MARK: - Attributed String Generation

    /// Generates an `AttributedString` for a paragraph with optional word highlighting.
    ///
    /// If `highlightedWordIndex` is nil or not within this paragraph's `wordRange`, returns
    /// a plain `AttributedString`. Otherwise, applies `.backgroundColor = .yellow.opacity(0.4)`
    /// and `.foregroundColor = .primary` to the highlighted word's character range.
    ///
    /// Highlight is applied instantly (no animation) per Research anti-pattern: animation at
    /// TTS speed causes visual lag.
    ///
    /// - Parameters:
    ///   - paragraph: The paragraph data containing text and cached tokens.
    ///   - highlightedWordIndex: The global word index to highlight, or nil for no highlight.
    /// - Returns: An `AttributedString` ready for display in a `Text` view.
    func attributedString(for paragraph: ParagraphData, highlightedWordIndex: Int?) -> AttributedString {
        var attributed = AttributedString(paragraph.text)

        guard let highlightIndex = highlightedWordIndex,
              paragraph.wordRange.contains(highlightIndex) else {
            return attributed
        }

        // Compute local index within this paragraph's cached tokens
        let localIndex = highlightIndex - paragraph.wordRange.lowerBound
        guard localIndex < paragraph.cachedTokens.count else { return attributed }

        let token = paragraph.cachedTokens[localIndex]

        // Convert String.Index range to AttributedString.Index range
        if let lower = AttributedString.Index(token.range.lowerBound, within: attributed),
           let upper = AttributedString.Index(token.range.upperBound, within: attributed) {
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.4)
            attributed[lower..<upper].foregroundColor = .primary
        }

        return attributed
    }
}
