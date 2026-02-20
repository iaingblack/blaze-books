import SwiftUI

/// A sheet view displaying the book's table of contents as a selectable chapter list.
///
/// Shows all chapters sorted by index with the current chapter highlighted by a bookmark icon.
/// Selecting a chapter calls the `onChapterSelected` callback with the chapter's index.
struct TableOfContentsView: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onChapterSelected: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Lightweight value type for rendering chapter rows without SwiftData @Model
    /// Binding interference in ForEach.
    private struct ChapterRow: Identifiable {
        let id: UUID
        let title: String
        let index: Int
    }

    private var rows: [ChapterRow] {
        chapters
            .sorted { $0.index < $1.index }
            .map { ChapterRow(id: $0.id, title: $0.title, index: $0.index) }
    }

    var body: some View {
        NavigationStack {
            chapterList
                .navigationTitle("Table of Contents")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }

    private var chapterList: some View {
        let items = rows
        return List {
            ForEach(items) { row in
                chapterButton(for: row)
            }
        }
    }

    private func chapterButton(for row: ChapterRow) -> some View {
        Button {
            onChapterSelected(row.index)
        } label: {
            HStack {
                Text(row.title)
                    .foregroundStyle(.primary)
                Spacer()
                if row.index == currentChapterIndex {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
