import SwiftData
import SwiftUI

@main
struct BlazeBooksApp: App {
    let modelContainer: ModelContainer
    @State private var importService = EPUBImportService()
    @State private var gutendexService = GutendexService()
    @State private var downloadService: BookDownloadService
    @State private var speedCapService = SpeedCapService()
    @State private var voiceManager = VoiceManager()
    @State private var readingCoordinator: ReadingCoordinator
    @State private var syncMonitor = SyncMonitorService()
    @State private var tipJar = TipJarService()

    init() {
        do {
            let config = ModelConfiguration(
                "BlazeBooks",
                cloudKitDatabase: .private("iCloud.com.blazebooks.BlazeBooks")
            )
            modelContainer = try ModelContainer(
                for: SchemaV4.Book.self,
                SchemaV4.Chapter.self,
                SchemaV4.ReadingPosition.self,
                SchemaV4.Shelf.self,
                migrationPlan: BlazeBooksMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Fallback: local-only container without CloudKit sync
            do {
                let fallbackConfig = ModelConfiguration("BlazeBooks")
                modelContainer = try ModelContainer(
                    for: SchemaV4.Book.self,
                    SchemaV4.Chapter.self,
                    SchemaV4.ReadingPosition.self,
                    SchemaV4.Shelf.self,
                    migrationPlan: BlazeBooksMigrationPlan.self,
                    configurations: fallbackConfig
                )
            } catch {
                // Last resort: in-memory container to prevent crash on launch
                modelContainer = try! ModelContainer(
                    for: SchemaV4.Book.self,
                    SchemaV4.Chapter.self,
                    SchemaV4.ReadingPosition.self,
                    SchemaV4.Shelf.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            }
        }

        // Create Phase 2 services
        let speedCap = SpeedCapService()
        _speedCapService = State(initialValue: speedCap)

        let voiceMgr = VoiceManager()
        _voiceManager = State(initialValue: voiceMgr)

        let coordinator = ReadingCoordinator(speedCapService: speedCap)
        _readingCoordinator = State(initialValue: coordinator)

        // Create Phase 6 services
        let importSvc = EPUBImportService()
        _importService = State(initialValue: importSvc)

        let downloadSvc = BookDownloadService(importService: importSvc)
        _downloadService = State(initialValue: downloadSvc)

        // Create Phase 7 services
        let syncMon = SyncMonitorService()
        _syncMonitor = State(initialValue: syncMon)

        let tip = TipJarService()
        _tipJar = State(initialValue: tip)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(importService)
                .environment(gutendexService)
                .environment(downloadService)
                .environment(speedCapService)
                .environment(voiceManager)
                .environment(readingCoordinator)
                .environment(syncMonitor)
                .environment(tipJar)
                .task {
                    migrateExistingBooksToEpubData(container: modelContainer)
                    syncMonitor.startMonitoring(container: modelContainer)
                    tipJar.start()
                }
        }
        .modelContainer(modelContainer)
    }

    /// Migrates existing books from file-path storage to epubData storage.
    /// Runs once after the V3->V4 migration. Books with epubData already set are skipped.
    @MainActor
    private func migrateExistingBooksToEpubData(container: ModelContainer) {
        let context = container.mainContext
        do {
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate<Book> { book in
                    book.epubData == nil
                }
            )
            let booksToMigrate = try context.fetch(descriptor)
            guard !booksToMigrate.isEmpty else { return }

            for book in booksToMigrate {
                guard !book.filePath.isEmpty else { continue }
                let fileURL = FileStorageManager.localURL(for: book.filePath)
                if let data = try? Data(contentsOf: fileURL) {
                    book.epubData = data
                }
            }
            try context.save()
        } catch {
            // Migration is best-effort; books without epubData will show cloud badge
            #if DEBUG
            print("EPUB data migration error: \(error)")
            #endif
        }
    }
}
