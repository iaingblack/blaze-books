import SwiftUI

/// A collapsible shelf section displaying its books in a cover grid.
///
/// Uses `DisclosureGroup` with expansion state managed by the parent via binding.
/// The section header shows the shelf name with a context menu for rename/delete.
/// Each book cover inside has a context menu for shelf assignment and deletion
/// (closures passed through from the parent `LibraryView`).
struct ShelfSectionView: View {
    let shelf: Shelf
    @Binding var isExpanded: Bool
    let shelves: [Shelf]

    // Shelf management callbacks
    var onRenameShelf: ((Shelf) -> Void)?
    var onDeleteShelf: ((Shelf) -> Void)?

    // Book management callbacks (wired in Task 2 with context menus)
    var onDeleteBook: ((Book) -> Void)?
    var onAddBookToShelf: ((Book, Shelf) -> Void)?
    var onRemoveBookFromShelf: ((Book, Shelf) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            shelfContent
        } label: {
            shelfLabel
        }
        .padding(.horizontal)
    }

    // MARK: - Shelf Label

    private var shelfLabel: some View {
        Text(shelf.name)
            .font(.title3)
            .bold()
            .contextMenu {
                Button {
                    onRenameShelf?(shelf)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDeleteShelf?(shelf)
                } label: {
                    Label("Delete Shelf", systemImage: "trash")
                }
            }
    }

    // MARK: - Shelf Content

    private var shelfContent: some View {
        Group {
            let books = shelf.books ?? []
            if books.isEmpty {
                Text("No books")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(books) { book in
                        NavigationLink(value: book) {
                            BookCoverView(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
