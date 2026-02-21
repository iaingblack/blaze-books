import SwiftUI
import SwiftData

// MARK: - Sort Options

/// Sort options for the All Books grid.
enum BookSortOption: String, CaseIterable {
    case recent = "Recently Read"
    case title = "Title"
    case author = "Author"
    case dateAdded = "Date Added"
}

/// Displays imported books in a sectioned library layout (like Apple Books).
///
/// Layout (top to bottom):
/// 1. **Continue Reading** -- horizontal scroll of up to 4 recently read books with progress bars
/// 2. **Shelf Sections** -- (placeholder for Plan 02)
/// 3. **All Books** -- sortable grid of all imported books
///
/// Uses `@Query` to fetch all books sorted by import date (newest first).
/// Shows an empty state when no books are imported. Each book cover links
/// to the reading view. Import errors and success indicators are shown
/// as alerts/toasts.
struct LibraryView: View {
    @Query(sort: \Book.importDate, order: .reverse) private var books: [Book]
    @Query(sort: \Shelf.createdDate) private var shelves: [Shelf]
    @Environment(EPUBImportService.self) private var importService
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var recentlyImportedBookID: UUID?
    @State private var sortOption: BookSortOption = .dateAdded

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    // MARK: - Computed Properties

    /// Books with reading progress > 0%, sorted by most recently read, limited to 4.
    private var continueReadingBooks: [Book] {
        books
            .filter { book in
                guard let pos = book.readingPosition else { return false }
                return pos.chapterIndex > 0 || pos.wordIndex > 0
            }
            .sorted { a, b in
                (a.readingPosition?.lastReadDate ?? .distantPast) >
                (b.readingPosition?.lastReadDate ?? .distantPast)
            }
            .prefix(4)
            .map { $0 }
    }

    /// All books sorted by the current sort option.
    private var sortedBooks: [Book] {
        switch sortOption {
        case .recent:
            return books.sorted { a, b in
                (a.readingPosition?.lastReadDate ?? .distantPast) >
                (b.readingPosition?.lastReadDate ?? .distantPast)
            }
        case .title:
            return books.sorted { a, b in
                a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .author:
            return books.sorted { a, b in
                a.author.localizedCaseInsensitiveCompare(b.author) == .orderedAscending
            }
        case .dateAdded:
            return books.sorted { a, b in
                a.importDate > b.importDate
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if books.isEmpty && !importService.isImporting {
                emptyState
            } else {
                sectionedLibrary
            }
        }
        .navigationTitle("Blaze Books")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                sortMenu
            }
            ToolbarItem(placement: .primaryAction) {
                ImportButton()
            }
        }
        .onChange(of: importService.importError) { _, newError in
            if let error = newError {
                errorMessage = error
                showingError = true
                // Clear the error after showing
                importService.importError = nil
            }
        }
        .onChange(of: importService.importSuccess) { _, success in
            if success {
                // Find the most recently imported book and animate it
                if let newestBook = books.first {
                    recentlyImportedBookID = newestBook.id
                    // Clear the highlight after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            recentlyImportedBookID = nil
                        }
                    }
                }
                importService.importSuccess = false
            }
        }
        .alert("Import Issue", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Sectioned Library

    private var sectionedLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Continue Reading section (only shows if books have progress)
                ContinueReadingSection(books: continueReadingBooks)

                // MARK: - Shelf Sections
                // Shelf sections will be added in Plan 02

                // 2. All Books section
                allBooksSection
            }
            .padding(.top, 8)
        }
    }

    // MARK: - All Books Section

    private var allBooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Books")
                .font(.title3)
                .bold()
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(sortedBooks) { book in
                    NavigationLink(value: book) {
                        BookCoverView(
                            book: book,
                            isImporting: importService.isImporting && book.id == books.first?.id && importService.importSuccess == false
                        )
                        .scaleEffect(recentlyImportedBookID == book.id ? 1.05 : 1.0)
                        .animation(.spring(duration: 0.4), value: recentlyImportedBookID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(BookSortOption.allCases, id: \.self) { option in
                Button {
                    sortOption = option
                } label: {
                    if sortOption == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No books yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Tap + to import an EPUB from your files.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}
