import SwiftUI
import SwiftData

/// Entry point for book discovery. Displays a grid of genre cards instantly
/// using static Genre data -- no API calls, no loading state.
///
/// Includes a search bar that queries the Gutendex API for books by title or
/// author. When searching, the genre grid is replaced with search results.
struct DiscoveryView: View {
    @Environment(GutendexService.self) private var gutendexService
    @Environment(GutenbergOPDSService.self) private var opdsService
    @Environment(BookDownloadService.self) private var downloadService
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryBooks: [Book]

    @State private var searchText = ""
    @State private var searchResults: [GutendexBook] = []
    @State private var nextPageURL: String?
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var hasSearched = false
    @State private var selectedBook: GutendexBook?
    @State private var searchTask: Task<Void, Never>?

    private let genreColumns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    private let searchColumns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if searchText.isEmpty {
                genreGrid
            } else if isSearching && searchResults.isEmpty {
                loadingView
            } else if searchFailed && searchResults.isEmpty {
                errorView
            } else if hasSearched && searchResults.isEmpty {
                emptyView
            } else {
                searchResultsGrid
            }
        }
        .navigationTitle("Discover Books")
        .searchable(text: $searchText, prompt: "Search books & authors")
        .onSubmit(of: .search) {
            guard !searchText.isEmpty else { return }
            searchTask?.cancel()
            searchTask = Task {
                await performSearch(query: searchText)
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchTask?.cancel()
                searchResults = []
                nextPageURL = nil
                hasSearched = false
                searchFailed = false
            }
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

    // MARK: - Genre Grid

    private var genreGrid: some View {
        LazyVGrid(columns: genreColumns, spacing: 12) {
            ForEach(Genre.all) { genre in
                NavigationLink {
                    GenreBooksView(genre: genre)
                } label: {
                    GenreCardView(genre: genre, coverURLs: [])
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Search Results Grid

    private var searchResultsGrid: some View {
        LazyVGrid(columns: searchColumns, spacing: 20) {
            ForEach(searchResults) { book in
                Button {
                    selectedBook = book
                } label: {
                    bookCard(for: book)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if book.id == searchResults.last?.id {
                        loadNextPage()
                    }
                }
            }

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)
            ProgressView("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Could not load results")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button("Retry") {
                searchFailed = false
                searchTask = Task {
                    await performSearch(query: searchText)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No books found")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Book Card

    private func bookCard(for book: GutendexBook) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
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

            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

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

    // MARK: - Search

    private func performSearch(query: String) async {
        isSearching = true
        searchFailed = false
        defer { isSearching = false }

        let result = await opdsService.searchBooks(query: query)
        guard !Task.isCancelled else { return }

        if let result {
            searchResults = result.books
            nextPageURL = result.nextPageURL
            hasSearched = true
        } else {
            searchFailed = true
            hasSearched = true
        }
    }

    private func loadNextPage() {
        guard let url = nextPageURL, !isSearching else { return }
        Task {
            isSearching = true
            defer { isSearching = false }

            let result = await opdsService.fetchNextPage(from: url)
            guard !Task.isCancelled else { return }

            if let result {
                searchResults.append(contentsOf: result.books)
                nextPageURL = result.nextPageURL
            }
        }
    }

    // MARK: - In Library Detection

    private func isInLibrary(_ gutendexBook: GutendexBook) -> Bool {
        libraryBooks.contains { $0.gutenbergId == gutendexBook.id }
    }
}
