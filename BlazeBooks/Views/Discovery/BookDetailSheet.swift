import SwiftUI

/// Sheet presenting book details with cover, title, author, and a download/status button.
///
/// Button states:
/// - Default: "Download" (prominent style, triggers onDownload)
/// - Downloading: ProgressView with "Downloading..." label
/// - Importing: ProgressView with "Importing..." label
/// - Completed / In Library: "In Library" badge (green, disabled)
/// - Failed: "Retry" button with error message
///
/// An info toggle reveals subjects and bookshelves from the Gutendex metadata.
struct BookDetailSheet: View {
    let book: GutendexBook
    let isInLibrary: Bool
    let downloadState: BookDownloadService.DownloadState?
    let onDownload: () -> Void

    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Cover image
                    coverImage
                        .padding(.top, 24)

                    // Title
                    Text(book.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Author
                    Text(book.primaryAuthor)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Info toggle
                    infoSection
                }
            }

            // Download button pinned at bottom
            downloadButton
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Cover Image

    private var coverImage: some View {
        Group {
            if let coverURL = book.coverImageURL {
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    case .failure:
                        placeholderCover
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                            ProgressView()
                        }
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    @unknown default:
                        placeholderCover
                    }
                }
            } else {
                placeholderCover
            }
        }
        .frame(width: 200)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }

    private var placeholderCover: some View {
        ZStack {
            let hash = abs(book.title.hashValue)
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
                .aspectRatio(2.0 / 3.0, contentMode: .fit)

            VStack(spacing: 8) {
                Spacer()
                Text(book.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 16)
                Text(book.primaryAuthor)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Info Section

    private var hasInfoDetails: Bool {
        !book.subjects.isEmpty || !book.bookshelves.isEmpty || book.downloadCount > 0
    }

    @ViewBuilder
    private var infoSection: some View {
        if hasInfoDetails {
            VStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInfo.toggle()
                    }
                } label: {
                    Label(
                        showInfo ? "Hide Details" : "More Info",
                        systemImage: showInfo ? "chevron.up" : "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }

                if showInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        if !book.subjects.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Subjects")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text(book.subjects.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }

                        if !book.bookshelves.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bookshelves")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text(book.bookshelves.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }

                        if book.downloadCount > 0 {
                            Text("Downloads: \(book.downloadCount.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Download Button

    @ViewBuilder
    private var downloadButton: some View {
        if isInLibrary || downloadState == .completed {
            // In Library badge
            Label("In Library", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

        } else if let state = downloadState {
            switch state {
            case .downloading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Downloading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)

            case .importing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Importing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)

            case .failed(let message):
                VStack(spacing: 6) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button {
                        onDownload()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

            case .completed:
                // Handled above, but needed for exhaustive switch
                EmptyView()
            }

        } else {
            // Default: Download button
            Button {
                onDownload()
            } label: {
                Label("Download", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
