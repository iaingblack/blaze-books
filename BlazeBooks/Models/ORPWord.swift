import Foundation

/// A word prepared for RSVP display with its Optimal Recognition Point calculated.
///
/// The ORP (Optimal Recognition Point) is the character position within the word where the reader's
/// eye should fixate. This is determined by a lookup table derived from the speedread open-source
/// implementation. The word is split into three segments around the ORP character for display:
/// `beforeORP` | `orpCharacter` | `afterORP`, allowing the ORP letter to be centered and highlighted.
struct ORPWord {
    /// The full word text.
    let text: String
    /// Zero-based character index of the ORP letter within the word.
    let orpIndex: Int
    /// Characters before the ORP letter (for right-aligned display).
    let beforeORP: String
    /// The single ORP character (displayed centered with accent color).
    let orpCharacter: String
    /// Characters after the ORP letter (for left-aligned display).
    let afterORP: String
    /// Whether this word ends a sentence (inherited from WordToken).
    let isSentenceEnd: Bool
    /// Global index of this word within the chapter's word array.
    let wordIndex: Int

    /// Creates an ORPWord from a WordToken by calculating the ORP position using a lookup table.
    ///
    /// Lookup table (from speedread open-source implementation):
    /// - Word length 1-2: ORP at position 0
    /// - Word length 3-6: ORP at position 1
    /// - Word length 7-10: ORP at position 2
    /// - Word length 11-13: ORP at position 3
    /// - Word length 14+: ORP at position 4
    ///
    /// - Parameter token: The tokenized word with index and sentence boundary information.
    /// - Returns: An ORPWord with calculated ORP segments ready for display.
    static func from(token: WordToken) -> ORPWord {
        let text = token.text
        let length = text.count
        let orp = orpPosition(forWordLength: length)

        let startIndex = text.startIndex
        let orpStringIndex = text.index(startIndex, offsetBy: orp)
        let afterORPIndex = text.index(after: orpStringIndex)

        let before = String(text[startIndex..<orpStringIndex])
        let orpChar = String(text[orpStringIndex])
        let after = String(text[afterORPIndex..<text.endIndex])

        return ORPWord(
            text: text,
            orpIndex: orp,
            beforeORP: before,
            orpCharacter: orpChar,
            afterORP: after,
            isSentenceEnd: token.isSentenceEnd,
            wordIndex: token.index
        )
    }

    /// Returns the zero-based character index of the ORP for a word of the given length.
    ///
    /// Source: speedread open-source implementation (https://github.com/pasky/speedread)
    static func orpPosition(forWordLength length: Int) -> Int {
        guard length > 0 else { return 0 }
        if length <= 2 { return 0 }
        if length <= 6 { return 1 }
        if length <= 10 { return 2 }
        if length <= 13 { return 3 }
        return 4
    }
}
