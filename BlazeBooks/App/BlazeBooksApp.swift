import SwiftData
import SwiftUI

@main
struct BlazeBooksApp: App {
    let modelContainer: ModelContainer
    @State private var importService = EPUBImportService()

    init() {
        do {
            let config = ModelConfiguration("BlazeBooks")
            modelContainer = try ModelContainer(
                for: SchemaV1.Book.self,
                SchemaV1.Chapter.self,
                SchemaV1.ReadingPosition.self,
                migrationPlan: BlazeBooksMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(importService)
        }
        .modelContainer(modelContainer)
    }
}
