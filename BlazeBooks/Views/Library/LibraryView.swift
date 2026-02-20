import SwiftUI
import SwiftData

/// Displays imported books in a cover-forward grid layout (like Apple Books).
///
/// Uses `@Query` to fetch all books sorted by import date (newest first).
/// Shows an empty state when no books are imported. Each book cover links
/// to the reading view. Import errors and success indicators are shown
/// as alerts/toasts.
struct LibraryView: View {
    @Query(sort: \Book.importDate, order: .reverse) private var books: [Book]
    @Environment(EPUBImportService.self) private var importService
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var recentlyImportedBookID: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        Group {
            if books.isEmpty && !importService.isImporting {
                emptyState
            } else {
                bookGrid
            }
        }
        .navigationTitle("Blaze Books")
        .toolbar {
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

    // MARK: - Book Grid

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(books) { book in
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
            .padding(.top, 8)
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
