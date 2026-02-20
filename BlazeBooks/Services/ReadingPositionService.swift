import Foundation
import Observation
import SwiftData

/// Tracks and persists reading position for the current book.
///
/// Uses debounced saves (minimum 2-second interval) to avoid excessive
/// SwiftData writes during scrolling. Stores verification snippet for
/// resilient position restore across tokenizer changes.
@Observable
final class ReadingPositionService {

    // MARK: - Observable State

    var currentChapterIndex: Int = 0
    var currentWordIndex: Int = 0
    var progress: Double = 0.0
    var overallProgress: Double = 0.0

    // MARK: - Private State

    @ObservationIgnored
    private var lastSaveTime: Date = .distantPast

    @ObservationIgnored
    private let saveDebounceInterval: TimeInterval = 2.0

    @ObservationIgnored
    private let tokenizer = WordTokenizer()

    // MARK: - Load Position

    /// Loads the saved reading position for the given book.
    ///
    /// If no position exists, creates one at (chapter 0, word 0).
    func loadPosition(for book: Book, modelContext: ModelContext) {
        if let position = book.readingPosition {
            currentChapterIndex = position.chapterIndex
            currentWordIndex = position.wordIndex
        } else {
            // Create a new position at the beginning
            let position = ReadingPosition(
                chapterIndex: 0,
                wordIndex: 0,
                verificationSnippet: ""
            )
            position.book = book
            book.readingPosition = position
            modelContext.insert(position)

            currentChapterIndex = 0
            currentWordIndex = 0
        }

        // Calculate initial progress
        updateProgressFromPosition(book: book)
    }

    // MARK: - Save Position

    /// Saves the current reading position, debounced to avoid excessive writes.
    ///
    /// Only writes to SwiftData if more than `saveDebounceInterval` seconds
    /// have elapsed since the last save.
    func savePosition(
        book: Book,
        chapterIndex: Int,
        scrollFraction: Double,
        chapterText: String,
        modelContext: ModelContext
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastSaveTime) >= saveDebounceInterval else {
            return
        }

        currentChapterIndex = chapterIndex

        // Approximate word index from scroll fraction
        let tokens = tokenizer.tokenize(chapterText)
        let wordIndex = tokens.isEmpty ? 0 : Int(scrollFraction * Double(tokens.count - 1))
        currentWordIndex = max(0, min(wordIndex, max(0, tokens.count - 1)))

        // Generate verification snippet
        let snippet = tokenizer.verificationSnippet(tokens: tokens, at: currentWordIndex)

        // Update the book's reading position in SwiftData
        if let position = book.readingPosition {
            position.chapterIndex = chapterIndex
            position.wordIndex = currentWordIndex
            position.verificationSnippet = snippet
            position.lastReadDate = now
        } else {
            let position = ReadingPosition(
                chapterIndex: chapterIndex,
                wordIndex: currentWordIndex,
                verificationSnippet: snippet
            )
            position.lastReadDate = now
            position.book = book
            book.readingPosition = position
            modelContext.insert(position)
        }

        lastSaveTime = now

        // Update progress
        updateProgressFromPosition(book: book)
    }

    // MARK: - Progress Calculation

    /// Updates progress values from scroll offset.
    func updateProgress(
        scrollFraction: Double,
        chapterIndex: Int,
        totalChapters: Int
    ) {
        progress = max(0, min(1, scrollFraction))

        guard totalChapters > 0 else {
            overallProgress = 0
            return
        }

        let chapterWeight = 1.0 / Double(totalChapters)
        overallProgress = (Double(chapterIndex) * chapterWeight) + (scrollFraction * chapterWeight)
        overallProgress = max(0, min(1, overallProgress))
    }

    // MARK: - Private

    private func updateProgressFromPosition(book: Book) {
        let chapters = book.chapters?.sorted(by: { $0.index < $1.index }) ?? []
        let totalChapters = chapters.count
        guard totalChapters > 0 else {
            progress = 0
            overallProgress = 0
            return
        }

        // Estimate chapter progress from word index
        if currentChapterIndex < chapters.count {
            let chapter = chapters[currentChapterIndex]
            if chapter.wordCount > 0 {
                progress = Double(currentWordIndex) / Double(chapter.wordCount)
            } else {
                progress = 0
            }
        }

        let chapterWeight = 1.0 / Double(totalChapters)
        overallProgress = (Double(currentChapterIndex) * chapterWeight) + (progress * chapterWeight)
        overallProgress = max(0, min(1, overallProgress))
    }
}
