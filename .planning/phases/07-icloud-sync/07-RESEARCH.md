# Phase 7: iCloud Sync - Research

**Researched:** 2026-02-21
**Domain:** SwiftData + CloudKit sync, iCloud file storage
**Confidence:** HIGH

## Summary

SwiftData has built-in CloudKit sync that requires minimal code -- the primary work is configuring Xcode capabilities and adapting the data model to CloudKit constraints. The current Blaze Books data model (SchemaV3) is already largely CloudKit-compatible: all relationships are optional, all properties have default values, and no `@Attribute(.unique)` is used. The main adaptation work involves storing EPUB files in a way that syncs across devices, adding a sync indicator to the UI, and implementing a download queue for the first-device experience.

The recommended architecture is a **hybrid approach**: SwiftData with CloudKit handles metadata sync (Book, Chapter, ReadingPosition, Shelf records), while EPUB files are stored as `@Attribute(.externalStorage)` binary data on the Book model, which Core Data/SwiftData automatically converts to CKAsset for CloudKit sync. This avoids the complexity of managing a separate iCloud Documents container while staying within CloudKit's generous CKAsset size limits (up to 50 MB per asset -- well within typical EPUB sizes of 0.5-5 MB).

**Primary recommendation:** Enable CloudKit on the existing SwiftData ModelContainer by adding iCloud + Background Modes capabilities and switching `ModelConfiguration` to use `.private("iCloud.com.blazebooks.BlazeBooks")`. Store EPUB file data as `@Attribute(.externalStorage)` on the Book model instead of referencing a file path. Adapt the schema for CloudKit constraints (SchemaV4).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Most recent reading position wins (last-write-wins by timestamp)
- Shelf assignments use last-action-wins per book per shelf
- Deletion propagates to all devices (delete wins)
- All conflicts resolved silently -- never prompt or notify the user
- EPUB files sync via iCloud alongside metadata (positions, shelves, book records)
- Gutenberg-downloaded books sync their EPUB files too (same as imported books)
- App settings (WPM, voice, font size) stay per-device and do NOT sync
- All books sync -- no limit, no user-controlled sync selection
- No iCloud account = app works normally with no error or prompt, sync just doesn't happen
- Sync works over any connection (Wi-Fi and cellular) -- no restrictions
- All books download automatically on new device (not on-demand)
- Non-blocking: library shows immediately with whatever has synced, books become readable as they download
- Books not yet downloaded show a cloud badge on the cover (tap to prioritize download)
- Books with reading progress download first (prioritize continue-reading books)
- Subtle sync indicator: small cloud icon or spinner in toolbar while syncing, disappears when done

### Claude's Discretion
- Background sync implementation (CloudKit push notifications vs polling vs on-foreground)
- CloudKit container and record type design
- Download queue management and retry logic
- Exact cloud badge icon design

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SYNC-01 | User's library syncs across devices via iCloud | SwiftData CloudKit auto-sync handles Book model sync. SchemaV4 with CloudKit-compatible constraints. ModelConfiguration with `.private()` CloudKit database. EPUB files as `@Attribute(.externalStorage)` auto-convert to CKAsset. |
| SYNC-02 | User's reading positions sync across devices via iCloud | ReadingPosition model already has `lastReadDate` timestamp for last-write-wins conflict resolution. CloudKit's default merge policy is last-writer-wins at the attribute level, matching user requirement. |
| SYNC-03 | User's shelves sync across devices via iCloud | Shelf model syncs via SwiftData CloudKit. Book-Shelf many-to-many relationship is already optional on both sides. `sortOrder` property handles ordering (CloudKit forbids ordered relationships). |
</phase_requirements>

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftData + CloudKit | iOS 17+ | Automatic metadata sync | Built-in framework, zero external dependencies. SwiftData wraps NSPersistentCloudKitContainer which handles all sync logic including push notifications, merge, conflict resolution. |
| iCloud Capability (CloudKit) | Xcode 15+ | CloudKit container access | Required Xcode capability for CloudKit sync. Provides the iCloud container identifier. |
| Background Modes (Remote Notifications) | iOS 17+ | Silent push notifications | Required for CloudKit to notify app of remote changes. System delivers notifications silently. |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `@Attribute(.externalStorage)` | SwiftData iOS 17+ | Binary data stored as CKAsset | For EPUB file data and cover images. Core Data auto-converts large binary data to CKAsset (>100KB threshold). CKAsset supports up to ~50MB per asset. |
| `NSPersistentStoreRemoteChange` notification | Foundation | Detect remote sync events | To drive the sync indicator UI. Posted when CloudKit delivers changes to the local store. |
| `NSMetadataQuery` / CloudKit event notifications | Foundation | Monitor sync state | For the sync indicator (syncing/idle). Use `eventChangedNotification` from NSPersistentCloudKitContainer to observe import/export events. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@Attribute(.externalStorage)` for EPUBs | iCloud Documents (ubiquity container) | Separate file sync system adds complexity. Must coordinate two sync mechanisms (SwiftData for metadata + iCloud Documents for files). Not recommended -- externalStorage/CKAsset is simpler. |
| `@Attribute(.externalStorage)` for EPUBs | Store EPUB as file path + manual CKAsset upload | Full control but massive complexity. Must write custom CloudKit record management, conflict resolution, download queue. Not recommended. |
| SwiftData CloudKit | SQLiteData (Point-Free) / CKSyncEngine | More control over sync behavior, per-field conflict resolution. But adds third-party dependency and significant migration work. Not recommended for this project's needs. |

**Installation:** No additional packages needed. SwiftData and CloudKit are system frameworks.

## Architecture Patterns

### Recommended Project Structure
```
BlazeBooks/
├── Models/
│   ├── SchemaV4.swift          # CloudKit-compatible schema
│   ├── SchemaV3.swift          # Existing schema (preserved for migration)
│   └── ...
├── Services/
│   ├── SyncMonitorService.swift    # Observes CloudKit sync events for UI
│   ├── EPUBImportService.swift     # Updated: stores EPUB data on model instead of file path
│   ├── FileStorageManager.swift    # Updated: reads from model data instead of file path
│   └── ...
├── Views/
│   ├── Library/
│   │   ├── BookCoverView.swift     # Updated: cloud badge overlay for undownloaded books
│   │   ├── LibraryView.swift       # Updated: sync indicator in toolbar
│   │   └── ...
│   └── ...
└── App/
    └── BlazeBooksApp.swift         # Updated: CloudKit ModelConfiguration
```

### Pattern 1: CloudKit-Enabled ModelConfiguration
**What:** Switch from local-only `ModelConfiguration` to CloudKit-synced configuration.
**When to use:** App startup -- single change in `BlazeBooksApp.init()`.
**Example:**
```swift
// Source: Apple Developer Documentation - Syncing model data across a person's devices
// BEFORE (current):
let config = ModelConfiguration("BlazeBooks")

// AFTER (Phase 7):
let config = ModelConfiguration(
    "BlazeBooks",
    cloudKitDatabase: .private("iCloud.com.blazebooks.BlazeBooks")
)
```

### Pattern 2: EPUB Data as External Storage
**What:** Store EPUB binary data directly on the Book model with `@Attribute(.externalStorage)` instead of storing a file path and managing files separately.
**When to use:** SchemaV4 migration. Core Data/SwiftData automatically converts large binary data (>100KB) to CKAsset for CloudKit sync.
**Example:**
```swift
@Model
final class Book {
    // ... existing properties ...

    @Attribute(.externalStorage)
    var epubData: Data?         // EPUB file binary data (auto-synced as CKAsset)

    var isDownloaded: Bool {    // Computed: is EPUB data available locally?
        epubData != nil
    }
}
```

### Pattern 3: Sync Monitor via CloudKit Event Notifications
**What:** Observe NSPersistentCloudKitContainer sync events to drive the sync indicator.
**When to use:** To show/hide the cloud sync indicator in the toolbar.
**Example:**
```swift
// Source: fatbobman.com - Mastering Data Tracking and Notifications
@Observable
final class SyncMonitorService {
    var isSyncing: Bool = false

    func startMonitoring(container: ModelContainer) {
        // Observe remote change notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChange"),
            object: container,
            queue: .main
        ) { [weak self] _ in
            self?.isSyncing = false  // Remote changes received = sync complete
        }
    }
}
```

### Pattern 4: Cloud Badge on BookCoverView
**What:** Overlay a small cloud icon on books whose EPUB data has not yet downloaded.
**When to use:** In BookCoverView when `book.epubData == nil` but the book record exists (synced metadata without file data).
**Example:**
```swift
// In BookCoverView, inside the cover ZStack:
if book.epubData == nil {
    // Cloud badge overlay
    VStack {
        HStack {
            Spacer()
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(6)
        }
        Spacer()
    }
}
```

### Anti-Patterns to Avoid
- **Storing file paths for synced content:** File paths are device-specific (Documents directory varies). Store binary data directly on the model with `@Attribute(.externalStorage)`. The `filePath` property becomes irrelevant for synced books.
- **Using `@Attribute(.unique)`:** CloudKit cannot enforce uniqueness across distributed devices. Never add `.unique` to any synced property. Use `fileHash` for application-level dedup instead.
- **Using `.deny` delete rule:** CloudKit does not support the deny delete rule. Current app uses `.cascade` and `.nullify` which are both compatible.
- **Ordered relationships:** CloudKit does not support ordered relationships. The current `[Chapter]?` relationship is unordered. Use `Chapter.index` for sorting (already the pattern in the codebase).
- **Relying on sync timing:** CloudKit sync is opportunistic and not real-time. Never assume data will be available within a specific timeframe. Design UI to gracefully handle partial sync states.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Metadata sync engine | Custom CloudKit record management | SwiftData + CloudKit auto-sync | CloudKit push notifications, merge policies, conflict resolution, retry logic are all handled automatically by NSPersistentCloudKitContainer |
| Conflict resolution | Custom timestamp comparison logic | CloudKit's built-in last-writer-wins at attribute level | Already matches the user's requirement (most recent wins). CloudKit handles this per-attribute automatically. |
| File sync for EPUBs | Custom CKAsset upload/download queue | `@Attribute(.externalStorage)` | Core Data automatically converts to CKAsset for CloudKit. System handles upload/download scheduling. |
| Schema initialization | Manual CloudKit record type creation | `initializeCloudKitSchema()` in DEBUG builds | System auto-creates CloudKit schema from SwiftData models. Manual init ensures complex relationships are captured. |
| Download prioritization | Custom download queue manager | CloudKit's natural sync order + UI-level "tap to prioritize" | CloudKit syncs metadata first (small), then assets (large). Books with recent reading positions naturally sync their metadata first. |

**Key insight:** SwiftData + CloudKit is designed to be zero-configuration sync. The entire sync engine, conflict resolution, push notification handling, and retry logic are built into the framework. Custom sync code almost always introduces bugs that Apple has already solved.

## Common Pitfalls

### Pitfall 1: CloudKit Schema Not Deployed to Production
**What goes wrong:** App syncs perfectly in development/Xcode but fails completely in TestFlight/App Store. No data appears on other devices.
**Why it happens:** CloudKit has separate development and production environments. Xcode automatically uses development. TestFlight/App Store uses production. The schema must be manually deployed from development to production via CloudKit Dashboard.
**How to avoid:** Before any TestFlight build: (1) Run `initializeCloudKitSchema()` in a DEBUG build to push schema to CloudKit development environment, (2) Open CloudKit Dashboard at icloud.developer.apple.com, (3) Click "Deploy Schema Changes..." to promote to production.
**Warning signs:** Sync works on simulator/device via Xcode but not via TestFlight.

### Pitfall 2: Schema is Additive-Only in Production
**What goes wrong:** After promoting CloudKit schema to production, you cannot delete entities, delete attributes, rename entities/attributes, or change attribute types. Attempting these causes sync failures.
**Why it happens:** CloudKit schemas are permanent once promoted to production. This ensures existing devices with old app versions can still sync.
**How to avoid:** Get the schema right before the first production deployment. Add new attributes with defaults. Deprecate old attributes in code but keep them in the model. The current migration from SchemaV3 to SchemaV4 is the last chance to restructure before production lock-in.
**Warning signs:** Xcode build errors about CloudKit schema compatibility.

### Pitfall 3: Missing @Attribute(.externalStorage) on Large Data
**What goes wrong:** Book cover images (coverImageData) and EPUB file data exceed the 1 MB CKRecord size limit, causing sync failures for individual records.
**Why it happens:** CloudKit limits each record to 1 MB of non-asset data. Without `.externalStorage`, binary data is stored inline in the record.
**How to avoid:** Mark all large `Data?` properties with `@Attribute(.externalStorage)`. This tells Core Data to store them as separate CKAsset files (up to ~50 MB each). Apply to both `epubData` and `coverImageData`.
**Warning signs:** Sync errors in console mentioning record size limits. Books with large covers or large EPUBs fail to sync while small ones succeed.

### Pitfall 4: Chapter Text Stored Inline Bloats Records
**What goes wrong:** The `Chapter.text` property stores full chapter text as a `String`. Long chapters can be hundreds of KB. With many chapters per book, this can cause slow sync and approach record limits.
**Why it happens:** Chapter text is stored as a regular String attribute in the SwiftData record. CloudKit syncs all attributes.
**How to avoid:** Two options: (1) Mark `Chapter.text` with `@Attribute(.externalStorage)` so large text is stored as CKAsset, or (2) Accept that chapter text syncs as regular attributes since they are typically under 1 MB each. Option 1 is safer. Core Data auto-converts strings approaching 1 MB to external assets during CloudKit serialization regardless.
**Warning signs:** Sync errors for books with very long chapters.

### Pitfall 5: Assuming Sync is Immediate
**What goes wrong:** UI code assumes data will be available on another device immediately after saving on the first device. User sees stale or missing data.
**Why it happens:** CloudKit sync is opportunistic. Apple deliberately throttles sync to balance system resources. Sync can take seconds to minutes depending on network conditions and system state.
**How to avoid:** Design all UI to handle partial sync states gracefully. Books that have synced metadata but not yet downloaded EPUB data should show a cloud badge. Never show error states for "not yet synced" conditions.
**Warning signs:** Users report data appearing late or never on second device.

### Pitfall 6: Testing Only in Simulator
**What goes wrong:** CloudKit sync appears to work in simulator but has subtle bugs on real devices, or vice versa.
**Why it happens:** CloudKit in the simulator has known reliability issues. The simulator does not accurately simulate network conditions, push notification delivery, or background sync behavior.
**How to avoid:** Always test sync on two physical devices signed into the same iCloud account. The development cycle should be: implement -> test on device A -> verify on device B.
**Warning signs:** "Works on my machine" but not on physical devices.

### Pitfall 7: filePath References Break Across Devices
**What goes wrong:** Book records sync but the `filePath` property points to a location that doesn't exist on the other device. EPUB files cannot be opened.
**Why it happens:** `filePath` currently stores a relative path in the app's Documents/Books/ directory. Each device has its own sandbox with different absolute paths. The EPUB file itself doesn't sync via SwiftData -- only the metadata does.
**How to avoid:** Replace `filePath` with `@Attribute(.externalStorage) var epubData: Data?` that stores the actual EPUB binary data. This data syncs as a CKAsset. The file path becomes unnecessary.
**Warning signs:** Books appear in library on second device but crash or show error when opened.

## Code Examples

Verified patterns from official sources and established community practices:

### Enabling CloudKit Sync on ModelContainer
```swift
// Source: Apple Developer Documentation - Syncing model data across a person's devices
// In BlazeBooksApp.init():
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
```

### SchemaV4 CloudKit-Compatible Model (Book)
```swift
// Key changes from SchemaV3:
// 1. Add @Attribute(.externalStorage) to coverImageData
// 2. Add epubData with @Attribute(.externalStorage) for EPUB file sync
// 3. Keep filePath for backward compatibility during migration
@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var filePath: String = ""     // Deprecated: kept for migration, not used for new books
    var importDate: Date = Date()
    var chapterCount: Int = 0
    var fileHash: String = ""
    var gutenbergId: Int?

    @Attribute(.externalStorage)
    var coverImageData: Data?     // Stored as CKAsset in CloudKit

    @Attribute(.externalStorage)
    var epubData: Data?           // EPUB file binary -- synced as CKAsset

    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter]? = []

    @Relationship(deleteRule: .cascade, inverse: \ReadingPosition.book)
    var readingPosition: ReadingPosition?

    @Relationship(deleteRule: .nullify, inverse: \Shelf.books)
    var shelves: [Shelf]? = []
}
```

### Initializing CloudKit Schema (Development Only)
```swift
// Source: fatbobman.com - Resolving Incomplete iCloud Data Sync
// Call once during development to push schema to CloudKit
#if DEBUG
@MainActor
func initializeCloudKitSchemaIfNeeded() {
    do {
        let desc = NSPersistentStoreDescription(url: config.url)
        let opts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.blazebooks.BlazeBooks"
        )
        desc.cloudKitContainerOptions = opts
        desc.shouldAddStoreAsynchronously = false

        if let mom = NSManagedObjectModel.makeManagedObjectModel(
            for: [Book.self, Chapter.self, ReadingPosition.self, Shelf.self]
        ) {
            let container = NSPersistentCloudKitContainer(
                name: "BlazeBooks", managedObjectModel: mom
            )
            container.persistentStoreDescriptions = [desc]
            container.loadPersistentStores { _, err in
                if let err { print("Schema init store error: \(err)") }
            }
            try container.initializeCloudKitSchema()

            // Release file locks
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    } catch {
        print("Schema init error: \(error)")
    }
}
#endif
```

### Observing Remote Sync Changes
```swift
// Source: fatbobman.com - Mastering Data Tracking and Notifications
// SwiftData + CloudKit auto-enables NSPersistentStoreRemoteChangeNotificationPostOptionKey
NotificationCenter.default.addObserver(
    forName: .NSPersistentStoreRemoteChange,
    object: modelContainer.mainContext.coordinator,
    queue: .main
) { notification in
    // Remote changes received -- update sync indicator
    print("Remote changes imported")
}
```

### Handling No iCloud Account Gracefully
```swift
// Source: Apple Developer Documentation
// When CloudKit is configured but no iCloud account is signed in,
// SwiftData silently falls back to local-only storage.
// No code needed -- this is the default behavior.
// The app works normally without any error or prompt.
```

### Import Service Update: Storing EPUB Data on Model
```swift
// Updated EPUBImportService.importLocalEPUB -- store binary data instead of file path
func importLocalEPUB(at localURL: URL, modelContext: ModelContext, ...) async throws {
    // ... existing hash check and parsing ...

    // Read EPUB file data
    let epubData = try Data(contentsOf: localURL)

    let book = Book(
        title: title,
        author: author,
        filePath: localURL.lastPathComponent,  // Keep for backward compat
        coverImageData: coverData,
        fileHash: fileHash,
        gutenbergId: gutenbergId
    )
    book.epubData = epubData  // Store binary data for CloudKit sync

    // ... rest of import (chapters, reading position) ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSUbiquitousKeyValueStore for small data | SwiftData + CloudKit auto-sync | iOS 17 (2023) | Full model sync without manual CloudKit code |
| CKSyncEngine for custom sync | SwiftData auto-sync via NSPersistentCloudKitContainer | iOS 17+ | Automatic sync for SwiftData models. CKSyncEngine is for custom CloudKit-only apps. |
| Manual CKRecord/CKAsset management | `@Attribute(.externalStorage)` auto-converts to CKAsset | Core Data + CloudKit (iOS 13+, carried into SwiftData) | No manual CloudKit code for binary data sync |
| iCloud Documents for file sync | `@Attribute(.externalStorage)` CKAsset | Modern recommendation | Simpler than maintaining two sync systems. Single source of truth. |

**Deprecated/outdated:**
- Manual NSPersistentCloudKitContainer setup: SwiftData handles this automatically via ModelConfiguration
- UIDocument / NSFilePresenter for iCloud sync: Replaced by SwiftData CloudKit for structured data
- NSUbiquitousKeyValueStore for settings: Not needed here since settings are per-device (user decision)

## Open Questions

1. **`@Attribute(.externalStorage)` CloudKit reliability for EPUB-sized files**
   - What we know: Core Data with "allows external storage" creates CKAsset for CloudKit sync. CKAsset supports up to ~50 MB. Typical EPUBs are 0.5-5 MB.
   - What's unclear: SwiftData's `@Attribute(.externalStorage)` is the SwiftData equivalent, but community reports on reliability with CloudKit sync are sparse. Apple's documentation confirms it exists but doesn't explicitly discuss CloudKit behavior.
   - Recommendation: Implement with `.externalStorage` and test thoroughly on physical devices. The underlying Core Data behavior is well-documented and this approach is the standard pattern. If issues arise, fallback to iCloud Documents container is possible but significantly more complex. **Confidence: MEDIUM-HIGH** -- the Core Data equivalent is proven, and SwiftData wraps Core Data.

2. **Migration from filePath to epubData**
   - What we know: SchemaV3 stores `filePath: String`. SchemaV4 needs `epubData: Data?`. This is an additive change (adding a new property) which is CloudKit-compatible.
   - What's unclear: Whether to run a one-time migration that reads existing EPUB files from disk and populates `epubData`, or to lazily populate on first access.
   - Recommendation: Run a one-time migration on first launch after update. Read each book's EPUB file from `FileStorageManager.booksDirectory + filePath`, store as `epubData`, then optionally clean up the loose file. This ensures existing books sync immediately.

3. **Download prioritization for books with reading progress**
   - What we know: User wants books with reading progress to download first on a new device.
   - What's unclear: CloudKit does not expose download queue ordering APIs. CKAsset downloads are managed by the system.
   - Recommendation: CloudKit naturally syncs metadata (small records) before assets (large CKAssets). Since ReadingPosition records are tiny, they sync first. The UI can use the presence of a ReadingPosition with `wordIndex > 0` to visually prioritize showing "in-progress" books. Actual CKAsset download order is system-managed. The "tap to prioritize" feature can trigger a re-read of the book's record which may nudge the system, but true priority control is not available.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: "Syncing model data across a person's devices" -- ModelConfiguration CloudKit setup, capability requirements, schema compatibility rules
- Context7 `/websites/developer_apple_swiftdata` -- ModelConfiguration API, CloudKitDatabase options, @Attribute(.externalStorage), schema constraints
- Apple Developer Documentation: "Preserving your app's model data across launches" -- Automatic iCloud sync entitlement detection

### Secondary (MEDIUM confidence)
- [Hacking with Swift: How to sync SwiftData with iCloud](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud) -- Setup steps, model constraints (no unique, optional relationships, default values)
- [fatbobman.com: Designing Models for CloudKit Sync](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) -- Comprehensive model constraint rules, additive-only schema rule
- [fatbobman.com: initializeCloudKitSchema](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/) -- Schema initialization code pattern for SwiftData
- [fatbobman.com: In-Depth Guide to iCloud Documents](https://fatbobman.com/en/posts/in-depth-guide-to-icloud-documents/) -- iCloud Documents alternative approach (not recommended but researched)
- [leojkwan.com: Deploy CloudKit-backed SwiftData entities to production](https://www.leojkwan.com/swiftdata-cloudkit-deploy-schema-changes/) -- Production deployment workflow
- [fatbobman.com: Mastering Data Tracking and Notifications](https://fatbobman.com/en/posts/mastering-data-tracking-and-notifications-in-core-data-and-swiftdata/) -- NSPersistentStoreRemoteChange observation pattern

### Tertiary (LOW confidence)
- Community forum reports on `@Attribute(.externalStorage)` + CloudKit: Sparse real-world reports. Core Data equivalent is well-proven. SwiftData wraps Core Data, so behavior should be equivalent. Flagged for physical device validation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- SwiftData + CloudKit is Apple's official recommended approach. Well-documented setup steps.
- Architecture: HIGH -- The hybrid approach (SwiftData metadata + externalStorage for files) is the standard Core Data + CloudKit pattern. Current model is already ~95% CloudKit-compatible.
- Pitfalls: HIGH -- CloudKit pitfalls are extremely well-documented across Apple forums, developer blogs, and official docs. Schema deployment to production is the most commonly missed step.
- EPUB file sync via externalStorage: MEDIUM -- Core Data equivalent is proven. SwiftData wraps Core Data. But limited SwiftData-specific real-world reports for files this size.

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (30 days -- stable domain, Apple frameworks)
