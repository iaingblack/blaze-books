import SwiftUI

/// Entry point for book discovery. Displays a grid of genre cards, each leading
/// to a genre-specific book grid (GenreBooksView).
///
/// On appear, fires parallel API requests (batched 4-5 at a time) for each genre
/// to fetch 2-3 cover image URLs per genre card. Shows a loading state while
/// initial genre covers are being fetched.
struct DiscoveryView: View {
    @Environment(GutendexService.self) private var gutendexService

    /// Maps genre topic to an array of cover image URLs for the genre card collage.
    @State private var genreCovers: [String: [URL]] = [:]
    @State private var isLoadingCovers = true

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if isLoadingCovers && genreCovers.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 80)
                    ProgressView("Loading genres...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Genre.all) { genre in
                        NavigationLink(value: genre) {
                            GenreCardView(
                                genre: genre,
                                coverURLs: genreCovers[genre.topic] ?? []
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Discover Books")
        .navigationDestination(for: Genre.self) { genre in
            GenreBooksView(genre: genre)
        }
        .task {
            await loadGenreCovers()
        }
    }

    // MARK: - Load Genre Covers

    /// Fetches page 1 of each genre in batches of 4 to stay within rate limits,
    /// extracting 2-3 cover image URLs per genre for the card collage.
    private func loadGenreCovers() async {
        guard genreCovers.isEmpty else { return }

        let genres = Genre.all
        let batchSize = 4

        for batchStart in stride(from: 0, to: genres.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, genres.count)
            let batch = Array(genres[batchStart..<batchEnd])

            await withTaskGroup(of: (String, [URL]).self) { group in
                for genre in batch {
                    group.addTask {
                        let response = await gutendexService.fetchBooks(topic: genre.topic, page: 1)
                        let coverURLs = (response?.results ?? [])
                            .compactMap { $0.coverImageURL }
                            .prefix(3)
                        return (genre.topic, Array(coverURLs))
                    }
                }

                for await (topic, urls) in group {
                    genreCovers[topic] = urls
                }
            }
        }

        isLoadingCovers = false
    }
}
