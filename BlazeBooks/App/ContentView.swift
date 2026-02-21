import SwiftUI

/// Root view wrapping LibraryView in a NavigationStack with navigation
/// destinations for the reading view.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: Book.self) { book in
                    ReadingView(book: book)
                }
                .navigationDestination(for: Genre.self) { genre in
                    GenreBooksView(genre: genre)
                }
        }
    }
}

#Preview {
    ContentView()
}
