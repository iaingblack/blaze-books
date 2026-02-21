import SwiftUI
import SwiftData

/// Displays books within a selected genre as an infinite-scroll grid.
///
/// Loads the initial page from GutendexService on appear, then fetches additional
/// pages when the user scrolls to the last visible book. Books already in the
/// user's library are detected via gutenbergId matching and show an "In Library"
/// badge in the detail sheet.
struct GenreBooksView: View {
    let genre: Genre

    @Environment(GutendexService.self) private var gutendexService
    @Environment(BookDownloadService.self) private var downloadService
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryBooks: [Book]

    @State private var books: [GutendexBook] = []
    @State private var isInitialLoad = true
    @State private var loadFailed = false
    @State private var selectedBook: GutendexBook? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if isInitialLoad && books.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 80)
                    ProgressView("Loading books...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if loadFailed && books.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 80)
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Could not load books")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Check your connection and try again.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Button("Retry") {
                        isInitialLoad = true
                        loadFailed = false
                        Task { await loadInitialBooks() }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if books.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 80)
                    Image(systemName: "books.vertical")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No books found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(books) { book in
                        Button {
                            selectedBook = book
                        } label: {
                            bookCard(for: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

            }
        }
        .navigationTitle(genre.name)
        .task {
            await loadInitialBooks()
        }
        .sheet(item: $selectedBook) { book in
            BookDetailSheet(
                book: book,
                isInLibrary: isInLibrary(book),
                downloadState: downloadService.activeDownloads[book.id],
                onDownload: {
                    Task {
                        await downloadService.downloadBook(book, modelContext: modelContext)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Book Card

    private func bookCard(for book: GutendexBook) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Cover image
                if let coverURL = book.coverImageURL {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                                .clipped()
                        case .failure:
                            placeholderCover(title: book.title)
                        case .empty:
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                ProgressView()
                            }
                        @unknown default:
                            placeholderCover(title: book.title)
                        }
                    }
                } else {
                    placeholderCover(title: book.title)
                }

                // In Library badge overlay
                if isInLibrary(book) || downloadService.activeDownloads[book.id] == .completed {
                    Text("In Library")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.green, in: Capsule())
                        .padding(6)
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            // Title
            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Author
            Text(book.primaryAuthor)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Placeholder Cover

    private func placeholderCover(title: String) -> some View {
        ZStack {
            let hash = abs(title.hashValue)
            let hue1 = Double(hash % 360) / 360.0
            let hue2 = Double((hash / 360) % 360) / 360.0

            RoundedRectangle(cornerRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue1, saturation: 0.6, brightness: 0.65),
                            Color(hue: hue2, saturation: 0.55, brightness: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 6) {
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 8)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Data Loading

    private func loadInitialBooks() async {
        guard books.isEmpty else { return }
        loadFailed = false

        let response = await gutendexService.fetchBooksByIds(genre.bookIds)
        if let response = response {
            books = response.results.filter { $0.epubURL != nil }
            isInitialLoad = false
        } else if !Task.isCancelled {
            // Only treat as failure if the task was not cancelled
            // (cancelled tasks will re-run when SwiftUI re-creates .task)
            loadFailed = true
            isInitialLoad = false
        }
        // If Task.isCancelled, leave isInitialLoad = true so the
        // next .task invocation retries automatically
    }

    // MARK: - In Library Detection

    /// Checks if a Gutenberg book is already in the user's library by matching gutenbergId.
    private func isInLibrary(_ gutendexBook: GutendexBook) -> Bool {
        libraryBooks.contains { $0.gutenbergId == gutendexBook.id }
    }
}
