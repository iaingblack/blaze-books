import SwiftUI

/// Entry point for book discovery. Displays a grid of genre cards instantly
/// using static Genre data -- no API calls, no loading state.
///
/// Each genre card renders with a fallback gradient background and SF Symbol
/// icon. Tapping a card navigates to GenreBooksView for that genre.
struct DiscoveryView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Genre.all) { genre in
                    NavigationLink(value: genre) {
                        GenreCardView(genre: genre, coverURLs: [])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Discover Books")
        .navigationDestination(for: Genre.self) { genre in
            GenreBooksView(genre: genre)
        }
    }
}
