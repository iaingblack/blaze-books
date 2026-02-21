---
phase: 07-icloud-sync
plan: 01
subsystem: database
tags: [cloudkit, swiftdata, icloud, sync, migration, ckasset, external-storage]

# Dependency graph
requires:
  - phase: 06-book-discovery
    provides: SchemaV3 with gutenbergId, EPUBImportService with importLocalEPUB
  - phase: 01-foundation
    provides: SchemaV1 migration plan, ModelContainer setup, FileStorageManager
provides:
  - SchemaV4 with CloudKit-compatible attributes and externalStorage for EPUB data
  - CloudKit-enabled ModelConfiguration pointing to private iCloud database
  - Data migration from filePath-based storage to epubData-based storage
  - Updated import pipeline storing epubData on Book model
  - FileStorageManager.temporaryFileURL helper for Readium parsing from Data
affects: [07-02-PLAN (sync UI indicators depend on this data layer)]

# Tech tracking
tech-stack:
  added: [CloudKit, CKAsset (via externalStorage)]
  patterns: [SwiftData + CloudKit auto-sync, @Attribute(.externalStorage) for large binary data, one-time data migration via .task modifier]

key-files:
  created:
    - BlazeBooks/Models/SchemaV4.swift
    - BlazeBooks/BlazeBooks.entitlements
    - BlazeBooks/Info.plist
  modified:
    - BlazeBooks/Models/SchemaV1.swift
    - BlazeBooks/Models/Book.swift
    - BlazeBooks/Models/Chapter.swift
    - BlazeBooks/Models/ReadingPosition.swift
    - BlazeBooks/Models/Shelf.swift
    - BlazeBooks/App/BlazeBooksApp.swift
    - BlazeBooks/Services/EPUBImportService.swift
    - BlazeBooks/Utilities/FileStorageManager.swift
    - BlazeBooks.xcodeproj/project.pbxproj

key-decisions:
  - "epubData as @Attribute(.externalStorage) Data? on Book for CloudKit CKAsset sync of EPUB binaries"
  - "Chapter.text marked @Attribute(.externalStorage) to prevent exceeding 1MB CKRecord limit"
  - "coverImageData marked @Attribute(.externalStorage) for same CKRecord size safety"
  - "Lightweight migration V3->V4 (only adding optional properties and attributes)"
  - "One-time data migration via .task modifier on ContentView reads existing filePath EPUBs into epubData"
  - "CloudKit private database iCloud.com.blazebooks.BlazeBooks -- no iCloud account degrades silently to local-only"

patterns-established:
  - "@Attribute(.externalStorage) pattern: use for any Data property that could exceed 1MB (EPUB files, cover images, chapter text)"
  - "One-time migration pattern: .task modifier on root view with guard check (skip if already migrated)"
  - "CloudKit container naming: iCloud.com.blazebooks.BlazeBooks"

requirements-completed: [SYNC-01, SYNC-02, SYNC-03]

# Metrics
duration: 8min
completed: 2026-02-21
---

# Phase 7 Plan 01: iCloud Sync Data Layer Summary

**SchemaV4 with CloudKit-enabled SwiftData sync: EPUB data as CKAsset via externalStorage, private iCloud database, and one-time migration from filePath to epubData storage**

## Performance

- **Duration:** ~8 min (across checkpoint pause)
- **Started:** 2026-02-21
- **Completed:** 2026-02-21
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments
- Created SchemaV4 with CloudKit-compatible attributes: epubData, coverImageData, and Chapter.text all use @Attribute(.externalStorage) for CKAsset sync
- Enabled CloudKit sync via ModelConfiguration with private database (iCloud.com.blazebooks.BlazeBooks)
- Built one-time data migration that reads existing EPUB files from filePath into epubData on first V4 launch
- Updated EPUBImportService to store epubData during import so new books sync immediately
- Configured Xcode capabilities: iCloud (CloudKit), Push Notifications, Background Modes (remote notifications)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SchemaV4 with CloudKit-compatible attributes and update migration plan** - `5e774a7` (feat)
2. **Task 2: Enable CloudKit ModelConfiguration, update import pipeline, and add data migration** - `1782a86` (feat)
3. **Task 3: Verify Xcode capabilities and CloudKit setup** - `fddae51` (chore)

## Files Created/Modified
- `BlazeBooks/Models/SchemaV4.swift` - CloudKit-compatible schema with epubData (externalStorage), coverImageData (externalStorage), Chapter.text (externalStorage)
- `BlazeBooks/Models/SchemaV1.swift` - Migration plan updated with V3->V4 lightweight stage
- `BlazeBooks/Models/Book.swift` - Typealias updated to SchemaV4.Book
- `BlazeBooks/Models/Chapter.swift` - Typealias updated to SchemaV4.Chapter
- `BlazeBooks/Models/ReadingPosition.swift` - Typealias updated to SchemaV4.ReadingPosition
- `BlazeBooks/Models/Shelf.swift` - Typealias updated to SchemaV4.Shelf
- `BlazeBooks/App/BlazeBooksApp.swift` - CloudKit ModelConfiguration, SchemaV4 types, data migration method
- `BlazeBooks/Services/EPUBImportService.swift` - Stores epubData on Book during import
- `BlazeBooks/Utilities/FileStorageManager.swift` - Added temporaryFileURL(from:filename:) helper
- `BlazeBooks/BlazeBooks.entitlements` - iCloud CloudKit container and push notification entitlements
- `BlazeBooks/Info.plist` - Background Modes with remote-notification
- `BlazeBooks.xcodeproj/project.pbxproj` - Entitlements and Info.plist references

## Decisions Made
- **epubData as externalStorage:** EPUB binary data stored directly on Book model with @Attribute(.externalStorage) -- CloudKit syncs this as a CKAsset, avoiding the 1MB CKRecord size limit
- **Chapter.text as externalStorage:** Long chapter text could approach 1MB; safer as CKAsset (Research Pitfall 4, Option 1)
- **coverImageData as externalStorage:** Cover images can be large; same CKRecord size safety
- **Lightweight V3->V4 migration:** Only adds optional properties (epubData) and attributes (externalStorage) -- no data transformation needed at schema level
- **One-time data migration via .task:** Reads existing filePath EPUBs into epubData on first launch post-update; skips books that already have epubData
- **Silent local-only fallback:** No iCloud account = app works normally. SwiftData+CloudKit degrades silently (Apple default behavior)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

Xcode capabilities were configured manually (Task 3 checkpoint):
- iCloud capability with CloudKit and container `iCloud.com.blazebooks.BlazeBooks`
- Background Modes capability with Remote notifications
- Push Notifications capability

## Next Phase Readiness
- CloudKit sync is active at the data layer -- all four model types (Book, Chapter, ReadingPosition, Shelf) sync automatically
- Plan 07-02 can now build sync UI indicators (cloud badges, sync status) on top of this foundation
- The `isDownloaded` computed property on Book is ready for Plan 02's undownloaded book guard

---
*Phase: 07-icloud-sync*
*Completed: 2026-02-21*
