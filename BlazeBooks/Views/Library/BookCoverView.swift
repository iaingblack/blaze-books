import SwiftUI

/// Displays a book's cover image or a generated placeholder.
///
/// Shows the book title below the cover. If the book is currently being
/// imported, overlays a ProgressView spinner.
struct BookCoverView: View {
    let book: Book
    var isImporting: Bool = false

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
