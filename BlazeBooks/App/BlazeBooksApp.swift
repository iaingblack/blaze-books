import SwiftData
import SwiftUI

@main
struct BlazeBooksApp: App {
    let modelContainer: ModelContainer
    @State private var importService = EPUBImportService()
    @State private var speedCapService = SpeedCapService()
    @State private var voiceManager = VoiceManager()
    @State private var readingCoordinator: ReadingCoordinator

    init() {
        do {
            let config = ModelConfiguration("BlazeBooks")
            modelContainer = try ModelContainer(
                for: SchemaV3.Book.self,
                SchemaV3.Chapter.self,
                SchemaV3.ReadingPosition.self,
                SchemaV3.Shelf.self,
                migrationPlan: BlazeBooksMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Create Phase 2 services
        let speedCap = SpeedCapService()
        _speedCapService = State(initialValue: speedCap)

        let voiceMgr = VoiceManager()
        _voiceManager = State(initialValue: voiceMgr)

        let coordinator = ReadingCoordinator(speedCapService: speedCap)
        _readingCoordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(importService)
                .environment(speedCapService)
                .environment(voiceManager)
                .environment(readingCoordinator)
        }
        .modelContainer(modelContainer)
    }
}
