import SwiftUI

/// Displays a genre card with a collage of 2-3 book cover images and the genre name
/// overlaid on a dark gradient at the bottom.
///
/// When no cover URLs are available, falls back to a gradient background with
/// the genre's SF Symbol icon and name.
struct GenreCardView: View {
    let genre: Genre
    let coverURLs: [URL]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if coverURLs.isEmpty {
                fallbackBackground
            } else {
                coverCollage
            }

            // Genre name overlay with dark gradient
            VStack {
                Spacer()
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)

                    Text(genre.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
        }
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    // MARK: - Cover Collage

    private var coverCollage: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(coverURLs.prefix(3).enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(genreGradient)
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        @unknown default:
                            Rectangle()
                                .fill(genreGradient)
                        }
                    }
                    .frame(
                        width: geometry.size.width / CGFloat(min(coverURLs.count, 3)),
                        height: geometry.size.height
                    )
                    .clipped()
                }
            }
        }
    }

    // MARK: - Fallback Background

    private var fallbackBackground: some View {
        ZStack {
            Rectangle()
                .fill(genreGradient)

            VStack(spacing: 8) {
                Image(systemName: genre.systemImage)
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))

                Text(genre.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Gradient

    private var genreGradient: LinearGradient {
        let hash = abs(genre.name.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0

        return LinearGradient(
            colors: [
                Color(hue: hue1, saturation: 0.55, brightness: 0.6),
                Color(hue: hue2, saturation: 0.5, brightness: 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
