import SwiftUI
import SwiftData

/// Scrollable reading view for displaying book chapter text with position tracking.
///
/// Placeholder implementation -- will be fully built in Task 2.
struct ReadingView: View {
    let book: Book

    var body: some View {
        Text("Reading: \(book.title)")
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
