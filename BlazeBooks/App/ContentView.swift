import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "books.vertical")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("No books yet.")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Import an EPUB to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationTitle("Blaze Books")
        }
    }
}

#Preview {
    ContentView()
}
