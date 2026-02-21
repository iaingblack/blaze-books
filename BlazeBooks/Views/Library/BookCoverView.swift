import SwiftUI

/// Displays a book's cover image or a generated placeholder.
///
/// Shows the book title below the cover. If the book is currently being
/// imported, overlays a ProgressView spinner.
///
/// When `onDelete` is non-nil, a long-press context menu provides:
/// - "Add to Shelf" submenu with toggle checkmarks for each shelf
/// - "Delete Book" destructive action
struct BookCoverView: View {
    let book: Book
    var isImporting: Bool = false
    var shelves: [Shelf] = []
    var onDelete: (() -> Void)? = nil
    var onAddToShelf: ((Shelf) -> Void)? = nil
    var onRemoveFromShelf: ((Shelf) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover image or placeholder
            ZStack {
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(2.0 / 3.0, contentMode: .fill)
                        .clipped()
                } else {
                    // Generated placeholder with color derived from title hash
                    placeholderCover
                }

                // Import progress overlay
                if isImporting {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }

                // Cloud badge for books not yet downloaded (synced metadata without EPUB data)
                if !book.isDownloaded {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            // Title below cover
            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Author below title
            Text(book.author)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .modifier(BookContextMenuModifier(
            book: book,
            shelves: shelves,
            onDelete: onDelete,
            onAddToShelf: onAddToShelf,
            onRemoveFromShelf: onRemoveFromShelf
        ))
    }

    // MARK: - Placeholder Cover

    private var placeholderCover: some View {
        ZStack {
            // Background color derived from title hash
            RoundedRectangle(cornerRadius: 0)
                .fill(placeholderGradient)

            VStack(spacing: 8) {
                Spacer()

                Text(book.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 12)

                if !book.author.isEmpty && book.author != "Unknown Author" {
                    Text(book.author)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                }

                Spacer()
            }
            .padding(.vertical, 12)
        }
    }

    /// Generates a consistent gradient from the book title.
    private var placeholderGradient: LinearGradient {
        let hash = abs(book.title.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0

        let color1 = Color(hue: hue1, saturation: 0.6, brightness: 0.65)
        let color2 = Color(hue: hue2, saturation: 0.55, brightness: 0.5)

        return LinearGradient(
            colors: [color1, color2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Context Menu Modifier

/// Conditionally applies a context menu to book covers when `onDelete` is provided.
///
/// Only shows the context menu in management contexts (Library grid, shelf sections)
/// -- not in ContinueReadingSection where management isn't needed.
private struct BookContextMenuModifier: ViewModifier {
    let book: Book
    let shelves: [Shelf]
    let onDelete: (() -> Void)?
    let onAddToShelf: ((Shelf) -> Void)?
    let onRemoveFromShelf: ((Shelf) -> Void)?

    func body(content: Content) -> some View {
        if let onDelete {
            content.contextMenu {
                // Shelf assignment submenu
                Menu("Add to Shelf") {
                    if shelves.isEmpty {
                        Text("No shelves")
                    } else {
                        ForEach(shelves) { shelf in
                            let isInShelf = shelf.books?.contains(where: { $0.id == book.id }) ?? false
                            Button {
                                if isInShelf {
                                    onRemoveFromShelf?(shelf)
                                } else {
                                    onAddToShelf?(shelf)
                                }
                            } label: {
                                if isInShelf {
                                    Label(shelf.name, systemImage: "checkmark")
                                } else {
                                    Text(shelf.name)
                                }
                            }
                        }
                    }
                }

                Divider()

                // Delete action
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Book", systemImage: "trash")
                }
            }
        } else {
            content
        }
    }
}
