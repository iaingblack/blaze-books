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

        // First pass: collect sentence end indices
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        sentenceTokenizer.setLanguage(.english)

        var sentenceEnds: Set<String.Index> = []
        sentenceTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { range, _ in
            sentenceEnds.insert(range.upperBound)
            return true
        }

        // Second pass: enumerate words with sentence boundary flags
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = text
        wordTokenizer.setLanguage(.english)

        var tokens: [WordToken] = []
        var wordIndex = 0

        wordTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { range, _ in
            let word = String(text[range])

            // Check if any sentence end falls within or at the end of this word's range
            let isSentenceEnd = sentenceEnds.contains { sentenceEnd in
                sentenceEnd >= range.lowerBound && sentenceEnd <= range.upperBound
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
