import SwiftUI

/// Horizontal scroll section showing recently read books with progress indicators.
///
/// Displays up to 4 books that have reading progress > 0%. Each book shows
/// its cover, a thin linear progress bar, and a percentage label. Tapping
/// navigates directly to the reading view. Only renders when the passed
/// array is non-empty.
struct ContinueReadingSection: View {
    let books: [Book]

    var body: some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continue Reading")
                    .font(.title3)
                    .bold()
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                continueReadingItem(for: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Continue Reading Item

    private func continueReadingItem(for book: Book) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BookCoverView(book: book)
                .frame(width: 100)

            let progress = computeOverallProgress(for: book)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .frame(width: 100)

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress Computation

    /// Computes overall reading progress from chapter position and word position.
    ///
    /// Formula: `(chapterIndex * chapterWeight) + (chapterProgress * chapterWeight)`
    /// where `chapterWeight = 1.0 / totalChapters` and
    /// `chapterProgress = wordIndex / chapter.wordCount`.
    private func computeOverallProgress(for book: Book) -> Double {
        guard let position = book.readingPosition else { return 0.0 }
        let chapters = (book.chapters ?? []).sorted { $0.index < $1.index }
        let totalChapters = chapters.count
        guard totalChapters > 0 else { return 0.0 }

        var chapterProgress = 0.0
        if position.chapterIndex < chapters.count {
            let chapter = chapters[position.chapterIndex]
            if chapter.wordCount > 0 {
                chapterProgress = Double(position.wordIndex) / Double(chapter.wordCount)
            }
        }

        let chapterWeight = 1.0 / Double(totalChapters)
        let overall = (Double(position.chapterIndex) * chapterWeight) + (chapterProgress * chapterWeight)
        return min(overall, 1.0)
    }
}
