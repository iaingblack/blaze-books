---
phase: 01-foundation
plan: 01
subsystem: foundation
tags: [swiftdata, swiftui, readium, epub, ios, spm, cryptokit]

# Dependency graph
requires:
  - phase: none
    provides: "First phase - no prior dependencies"
provides:
  - "Xcode project with iOS 17+ SwiftUI app target"
  - "Readium Swift Toolkit 3.7.0 SPM dependency (ReadiumShared, ReadiumStreamer)"
  - "SwiftData VersionedSchema (SchemaV1) with Book, Chapter, ReadingPosition models"
  - "BlazeBooksMigrationPlan for future schema migrations"
  - "FileStorageManager for Documents/Books/ directory management"
  - "ModelContainer configured and injected via SwiftUI .modelContainer()"
affects: [01-02, 01-03, phase-2, phase-3, phase-5, phase-7]

# Tech tracking
tech-stack:
  added: [Readium Swift Toolkit 3.7.0, SwiftData, SwiftUI, CryptoKit]
  patterns: [VersionedSchema, typealias model exposure, local-only ModelConfiguration]

key-files:
  created:
    - BlazeBooks.xcodeproj/project.pbxproj
    - BlazeBooks.xcodeproj/xcshareddata/xcschemes/BlazeBooks.xcscheme
    - BlazeBooks/App/BlazeBooksApp.swift
    - BlazeBooks/App/ContentView.swift
    - BlazeBooks/Models/SchemaV1.swift
    - BlazeBooks/Models/Book.swift
    - BlazeBooks/Models/Chapter.swift
    - BlazeBooks/Models/ReadingPosition.swift
    - BlazeBooks/Utilities/FileStorageManager.swift
    - .gitignore
  modified: []

key-decisions:
  - "Local-only ModelConfiguration for development; CloudKit database param deferred to Phase 7"
  - "Chapter.text stores full plain text at import time for offline reading without re-parsing"
  - "ReadingPosition.verificationSnippet for position resilience across tokenizer changes"
  - "SHA256 file hash via CryptoKit for duplicate EPUB detection"

patterns-established:
  - "VersionedSchema: All models defined inside SchemaV1 enum, exposed via typealiases"
  - "CloudKit-compatible: All properties have defaults or are optional, no @Attribute(.unique)"
  - "FileStorageManager: Static utility struct for Documents/Books/ directory management"

requirements-completed: [EPUB-04, LIB-05]

# Metrics
duration: 7min
completed: 2026-02-20
---

# Phase 1 Plan 01: Project Setup and Data Models Summary

**Xcode project with Readium Swift Toolkit 3.7.0, SwiftData VersionedSchema (Book/Chapter/ReadingPosition), and FileStorageManager for offline EPUB storage**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-20T15:42:57Z
- **Completed:** 2026-02-20T15:49:58Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- Xcode project builds and runs on iOS 17+ simulator (iPhone 16, iOS 18.4)
- Readium Swift Toolkit 3.7.0 resolves via SPM with all transitive dependencies (SwiftSoup, Fuzi, ZIPFoundation, etc.)
- SwiftData models follow VersionedSchema pattern with CloudKit-compatible properties
- Chapter model includes `text` field for storing full chapter content at import time
- ReadingPosition model includes `verificationSnippet` for position resilience
- FileStorageManager provides Documents/Books/ directory management and SHA256 hashing
- App launches to a placeholder NavigationStack with empty state message

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Xcode project with Readium SPM dependency** - `f4b1e4f` (feat)
2. **Task 2: Create SwiftData models with VersionedSchema and FileStorageManager** - `9e628a0` (feat)

## Files Created/Modified
- `BlazeBooks.xcodeproj/project.pbxproj` - Xcode project with iOS 17+ target, Readium SPM dependency
- `BlazeBooks.xcodeproj/xcshareddata/xcschemes/BlazeBooks.xcscheme` - Shared build scheme
- `BlazeBooks/App/BlazeBooksApp.swift` - App entry point with ModelContainer setup
- `BlazeBooks/App/ContentView.swift` - Placeholder NavigationStack with empty state
- `BlazeBooks/Models/SchemaV1.swift` - VersionedSchema with Book, Chapter, ReadingPosition, MigrationPlan
- `BlazeBooks/Models/Book.swift` - Typealias to SchemaV1.Book
- `BlazeBooks/Models/Chapter.swift` - Typealias to SchemaV1.Chapter
- `BlazeBooks/Models/ReadingPosition.swift` - Typealias to SchemaV1.ReadingPosition
- `BlazeBooks/Utilities/FileStorageManager.swift` - Documents/Books/ management, SHA256 hashing
- `.gitignore` - Xcode, SPM, macOS ignore patterns

## Decisions Made
- Used local-only `ModelConfiguration("BlazeBooks")` without `cloudKitDatabase` parameter to avoid needing CloudKit entitlements during development. CloudKit configuration deferred to Phase 7.
- Stored full chapter text in `Chapter.text` field at import time so reading view can display without re-parsing EPUB.
- Added `verificationSnippet` to ReadingPosition for resilience against NLTokenizer changes across iOS versions (per research Pitfall 5).
- Used SHA256 file hash (`fileHash` on Book) for duplicate detection since `@Attribute(.unique)` is incompatible with CloudKit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `xcode-select` pointed to CommandLineTools instead of Xcode.app. Resolved by using `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` environment variable for all xcodebuild invocations.
- Xcode 26.2 has simulator runtimes for both iOS 18.4 and iOS 26.2; needed to specify device by ID rather than name to avoid ambiguity.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Project foundation is complete: buildable Xcode project with Readium and SwiftData
- Ready for Plan 02: EPUB import service, Readium parser service, word tokenizer
- Ready for Plan 03: Library grid view, reading view with position tracking

## Self-Check: PASSED

All 10 created files verified on disk. Both task commits (f4b1e4f, 9e628a0) verified in git history. Clean build succeeds with zero errors.

---
*Phase: 01-foundation*
*Completed: 2026-02-20*
