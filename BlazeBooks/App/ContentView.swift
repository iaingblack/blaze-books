import SwiftUI

/// Root view wrapping LibraryView in a NavigationStack with navigation
/// destinations for the reading view.
///
/// Books whose EPUB data has not yet downloaded from iCloud show a
/// friendly placeholder instead of opening the reader.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: Book.self) { book in
                    if book.isDownloaded {
                        ReadingView(book: book)
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("Downloading from iCloud")
                                .font(.title3)
                                .fontWeight(.medium)
                            Text("\u{201C}\(book.title)\u{201D} is syncing from another device. It will be ready to read once the download completes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .navigationTitle(book.title)
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
