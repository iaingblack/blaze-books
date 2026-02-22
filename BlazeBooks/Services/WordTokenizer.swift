import Foundation
import NaturalLanguage

/// A single tokenized word with its position in the text and sentence boundary information.
struct WordToken {
    /// Zero-based index of this word in the tokenized text.
    let index: Int
    /// The actual word text.
    let text: String
    /// The range of this word in the original string.
    let range: Range<String.Index>
    /// Whether this word ends a sentence (the sentence boundary falls within or at the end of this word).
    let isSentenceEnd: Bool
}

/// Stateless tokenizer that splits text into indexed `WordToken` arrays using NLTokenizer.
///
/// Pinned to `.english` for deterministic tokenization across runs (per research Pitfall 5).
/// Can be made configurable in future phases for multi-language support.
struct WordTokenizer {

    /// Tokenizes the given text into an array of `WordToken` values.
    ///
    /// Uses a two-pass approach:
    /// 1. First pass with `NLTokenizer(unit: .sentence)` to collect sentence end indices.
    /// 2. Second pass with `NLTokenizer(unit: .word)` to enumerate words and flag sentence boundaries.
    func tokenize(_ text: String) -> [WordToken] {
        guard !text.isEmpty else { return [] }

        // First pass: collect sentence end indices in document order
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        sentenceTokenizer.setLanguage(.english)

        var sortedSentenceEnds: [String.Index] = []
        sentenceTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { range, _ in
            sortedSentenceEnds.append(range.upperBound)
            return true
        }

        // Second pass: enumerate words with sentence boundary flags.
        // Both words and sentence ends are in document order, so we advance
        // a pointer monotonically — O(n+m) instead of O(n*m).
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = text
        wordTokenizer.setLanguage(.english)

        var tokens: [WordToken] = []
        var wordIndex = 0
        var sentencePointer = 0

        wordTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { range, _ in
            let word = String(text[range])

            // Advance past sentence ends that fall before this word
            while sentencePointer < sortedSentenceEnds.count
                    && sortedSentenceEnds[sentencePointer] < range.lowerBound {
                sentencePointer += 1
            }

            // Check if the next sentence end falls within or at the end of this word
            let isSentenceEnd = sentencePointer < sortedSentenceEnds.count
                && sortedSentenceEnds[sentencePointer] <= range.upperBound

            // Consume the sentence end if it matched
            if isSentenceEnd {
                sentencePointer += 1
            }

            tokens.append(WordToken(
                index: wordIndex,
                text: word,
                range: range,
                isSentenceEnd: isSentenceEnd
            ))
            wordIndex += 1
            return true
        }

        return tokens
    }

    /// Counts words in the given text without allocating token objects.
    ///
    /// Uses a single `NLTokenizer(unit: .word)` pass with the same language
    /// settings as `tokenize()`, so counts are identical. No sentence detection,
    /// no object allocation — just counting.
    func countWords(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = text
        wordTokenizer.setLanguage(.english)

        var count = 0
        wordTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { _, _ in
            count += 1
            return true
        }
        return count
    }

    /// Returns a 3-word window around the given index for position verification.
    ///
    /// Used by `ReadingPosition` for resilient position restore: on restore, the app
    /// verifies that the word at the saved index matches this snippet. If not, it
    /// searches nearby for a match (per research Pitfall 5).
    func verificationSnippet(tokens: [WordToken], at index: Int) -> String {
        guard !tokens.isEmpty else { return "" }

        let clampedIndex = max(0, min(index, tokens.count - 1))
        let start = max(0, clampedIndex - 1)
        let end = min(tokens.count - 1, clampedIndex + 1)

        return tokens[start...end].map(\.text).joined(separator: " ")
    }
}
