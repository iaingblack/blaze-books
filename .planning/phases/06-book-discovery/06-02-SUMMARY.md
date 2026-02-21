---
phase: 06-book-discovery
plan: 02
subsystem: ui, services
tags: [swiftui, epub-download, urlsession, asyncimage, infinite-scroll, gutenberg, discovery, sheet-presentation]

# Dependency graph
requires:
  - phase: 06-book-discovery
    provides: "SchemaV3 with gutenbergId, GutendexModels, GutendexService API client"
  - phase: 05-library
    provides: "LibraryView, BookCoverView, LibraryService, EPUBImportService"
provides:
  - "BookDownloadService with DownloadState tracking and URLSession.download integration"
  - "EPUBImportService.importLocalEPUB shared import pipeline for downloaded EPUBs"
  - "DiscoveryView genre grid with cover collage cards"
  - "GenreBooksView infinite-scroll book grid with In Library detection"
  - "BookDetailSheet with download/progress/retry/completed states"
  - "LibraryView toolbar integration for Discovery navigation"
affects: [phase-7]

# Tech tracking
tech-stack:
  added: []
  patterns: [BookDownloadService download-import pipeline, importLocalEPUB shared method, genre cover collage prefetching, infinite scroll pagination, sheet presentation with detents, In Library gutenbergId detection]

key-files:
  created:
    - BlazeBooks/Services/BookDownloadService.swift
    - BlazeBooks/Views/Discovery/DiscoveryView.swift
    - BlazeBooks/Views/Discovery/GenreCardView.swift
    - BlazeBooks/Views/Discovery/GenreBooksView.swift
    - BlazeBooks/Views/Discovery/BookDetailSheet.swift
  modified:
    - BlazeBooks/Services/EPUBImportService.swift
    - BlazeBooks/Models/GutendexModels.swift
    - BlazeBooks/Views/Library/LibraryView.swift
    - BlazeBooks/App/BlazeBooksApp.swift

key-decisions:
  - "EPUBImportService refactored with importLocalEPUB shared method rather than duplicating import logic in BookDownloadService"
  - "ImportError enum (alreadyInLibrary, parseFailed) for structured error handling across import paths"
  - "BookDownloadService treats alreadyInLibrary as .completed (not error) for better UX"
  - "Genre made Hashable by topic for NavigationLink value support"
  - "Globe toolbar button in LibraryView for Discovery navigation (clean, alongside existing sort/shelf buttons)"
  - "Genre cover collage fetched in batches of 4 to respect Gutendex rate limits"

patterns-established:
  - "importLocalEPUB: shared import pipeline for both file-picker and download flows"
  - "BookDownloadService: @Observable with activeDownloads[Int: DownloadState] for per-book state tracking"
  - "Genre cover prefetching: TaskGroup batching on DiscoveryView appear"
  - "In Library detection: @Query Book records matched by gutenbergId"
  - "BookDetailSheet: sheet(item:) with presentationDetents([.medium, .large])"

requirements-completed: [DISC-01, DISC-02]

# Metrics
duration: 5min
completed: 2026-02-21
---

# Phase 6 Plan 02: Discovery UI & Download Pipeline Summary

**BookDownloadService with URLSession download-to-import pipeline, 4 Discovery SwiftUI views (genre grid, genre books, book detail sheet), and LibraryView toolbar integration for end-to-end Gutenberg book browsing and downloading**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-21T08:11:36Z
- **Completed:** 2026-02-21T08:17:30Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- EPUBImportService refactored with shared importLocalEPUB method that both file-picker and download flows use, eliminating logic duplication
- BookDownloadService created with DownloadState tracking (.downloading/.importing/.completed/.failed), URLSession.download integration, and import pipeline call
- DiscoveryView shows genre grid with cover collage cards fetched from Gutendex API in parallel batches
- GenreBooksView displays infinite-scroll book grid with In Library detection via gutenbergId matching
- BookDetailSheet presents book cover, title, author, subjects with download/progress/retry/In Library button states
- LibraryView toolbar now includes globe button navigating to DiscoveryView
- GutendexService and BookDownloadService injected via .environment() in BlazeBooksApp

## Task Commits

Each task was committed atomically:

1. **Task 1: Create BookDownloadService and refactor EPUBImportService** - `f0a0d7e` (feat)
2. **Task 2: Create Discovery UI views and integrate into LibraryView** - `9c98494` (feat)

## Files Created/Modified
- `BlazeBooks/Services/BookDownloadService.swift` - EPUB download orchestration with DownloadState tracking and import pipeline integration
- `BlazeBooks/Services/EPUBImportService.swift` - Refactored with importLocalEPUB shared method and ImportError enum
- `BlazeBooks/Views/Discovery/DiscoveryView.swift` - Genre grid entry point with cover collage prefetching
- `BlazeBooks/Views/Discovery/GenreCardView.swift` - Genre card with cover image collage and gradient name overlay
- `BlazeBooks/Views/Discovery/GenreBooksView.swift` - Infinite-scroll book grid for selected genre with In Library badges
- `BlazeBooks/Views/Discovery/BookDetailSheet.swift` - Sheet with book details and stateful download button
- `BlazeBooks/Models/GutendexModels.swift` - Added Hashable conformance to Genre for NavigationLink
- `BlazeBooks/Views/Library/LibraryView.swift` - Added globe toolbar button navigating to DiscoveryView
- `BlazeBooks/App/BlazeBooksApp.swift` - GutendexService and BookDownloadService injected into environment

## Decisions Made
- Refactored EPUBImportService with importLocalEPUB shared method instead of duplicating Book/Chapter/ReadingPosition creation logic in BookDownloadService (DRY, single source of truth for import pipeline)
- Added ImportError enum with alreadyInLibrary and parseFailed cases for structured error handling (enables BookDownloadService to treat duplicates as success)
- BookDownloadService treats ImportError.alreadyInLibrary as .completed state (book is already there, not an error from user perspective)
- Made Genre Hashable by topic (stable, unique) rather than UUID (regenerated each init) for NavigationLink value support
- Globe toolbar button (topBarLeading) chosen for Discovery navigation alongside existing sort and shelf buttons
- Genre cover collages fetched in batches of 4 genres at a time via TaskGroup to stay within Gutendex rate limits

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Hashable conformance to Genre**
- **Found during:** Task 2 (DiscoveryView creation)
- **Issue:** Genre used as NavigationLink value requires Hashable conformance; Genre only had Identifiable
- **Fix:** Added Hashable conformance with hash/equality based on topic (stable unique key)
- **Files modified:** BlazeBooks/Models/GutendexModels.swift
- **Verification:** Build succeeds, NavigationLink(value: genre) compiles
- **Committed in:** 9c98494 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minimal addition to make Genre work with SwiftUI navigation. No scope creep.

## Issues Encountered
None - both tasks compiled and verified on first build attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Complete book discovery flow operational: Library -> Genre Grid -> Genre Books -> Book Detail -> Download -> In Library
- DISC-01 (browse by genre) and DISC-02 (download free books) fully satisfied
- Phase 6 complete; ready for Phase 7 (CloudKit sync)
- BookDownloadService and GutendexService available in environment for any future extensions

## Self-Check: PASSED

All 9 files verified on disk. Both task commits (f0a0d7e, 9c98494) verified in git history. Clean build succeeds with zero errors.

---
*Phase: 06-book-discovery*
*Completed: 2026-02-21*
