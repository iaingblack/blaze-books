---
phase: 05-library
plan: 01
subsystem: database, ui
tags: [swiftdata, swiftui, schema-migration, versioned-schema, library-ui, progress-bar]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "SchemaV1 with Book, Chapter, ReadingPosition models and BlazeBooksMigrationPlan"
provides:
  - "SchemaV2 with Shelf model and many-to-many Book-Shelf relationship"
  - "Lightweight migration V1 -> V2"
  - "Sectioned LibraryView with Continue Reading and sortable All Books grid"
  - "ContinueReadingSection with progress bars and percentage labels"
  - "BookSortOption enum with 4 sort options"
affects: [05-02, phase-7]

# Tech tracking
tech-stack:
  added: []
  patterns: [SchemaV2 versioned schema, lightweight migration stage, sectioned library layout, computed progress from chapter/word position]

key-files:
  created:
    - BlazeBooks/Models/SchemaV2.swift
    - BlazeBooks/Models/Shelf.swift
    - BlazeBooks/Views/Library/ContinueReadingSection.swift
  modified:
    - BlazeBooks/Models/SchemaV1.swift
    - BlazeBooks/Models/Book.swift
    - BlazeBooks/Models/Chapter.swift
    - BlazeBooks/Models/ReadingPosition.swift
    - BlazeBooks/App/BlazeBooksApp.swift
    - BlazeBooks/Views/Library/LibraryView.swift

key-decisions:
  - ".nullify delete rules on both sides of Book-Shelf many-to-many (per research: cascade on many-to-many would delete books when shelf deleted)"
  - "Default relationship arrays to [] for iOS 17.0 alphabetical ordering bug workaround"
  - "Post-fetch sorting via computed properties instead of dynamic @Query sort descriptors"
  - "Progress computation from chapterIndex/wordIndex/chapter.wordCount at display time (not stored)"

patterns-established:
  - "SchemaV2: All models copied from V1 with additions, V1 frozen for migration"
  - "Continue Reading filter: readingPosition.chapterIndex > 0 || wordIndex > 0 excludes newly imported books"
  - "BookSortOption: enum-driven sort with computed property, Menu with checkmark in toolbar"

requirements-completed: [LIB-01, LIB-04]

# Metrics
duration: 3min
completed: 2026-02-21
---

# Phase 5 Plan 01: SchemaV2 and Sectioned Library Summary

**SchemaV2 with Shelf model, lightweight V1->V2 migration, and sectioned LibraryView with Continue Reading progress bars and 4-option sort menu**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-21T06:57:11Z
- **Completed:** 2026-02-21T07:00:51Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- SchemaV2 adds Shelf model with many-to-many Book relationship using .nullify delete rules on both sides
- Lightweight migration from V1 to V2 configured in BlazeBooksMigrationPlan
- LibraryView restructured into vertically stacked sections: Continue Reading at top, All Books grid at bottom
- Continue Reading shows up to 4 most recently read books with thin progress bars and percentage labels
- All Books grid sortable by recently read, title, author, or date added via toolbar Menu
- All existing import, navigation, and empty state functionality preserved

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SchemaV2 with Shelf model and update migration plan** - `d9d7591` (feat)
2. **Task 2: Restructure LibraryView with Continue Reading section and sort menu** - `48d5ae0` (feat)

## Files Created/Modified
- `BlazeBooks/Models/SchemaV2.swift` - SchemaV2 with Book (+ shelves relationship), Chapter, ReadingPosition, Shelf models
- `BlazeBooks/Models/Shelf.swift` - Typealias Shelf = SchemaV2.Shelf
- `BlazeBooks/Views/Library/ContinueReadingSection.swift` - Horizontal scroll section with progress bars and percentage labels
- `BlazeBooks/Models/SchemaV1.swift` - Updated BlazeBooksMigrationPlan with V1->V2 lightweight stage
- `BlazeBooks/Models/Book.swift` - Typealias updated to SchemaV2.Book
- `BlazeBooks/Models/Chapter.swift` - Typealias updated to SchemaV2.Chapter
- `BlazeBooks/Models/ReadingPosition.swift` - Typealias updated to SchemaV2.ReadingPosition
- `BlazeBooks/App/BlazeBooksApp.swift` - ModelContainer updated to SchemaV2 types including Shelf
- `BlazeBooks/Views/Library/LibraryView.swift` - Sectioned layout with Continue Reading, sort menu, All Books grid

## Decisions Made
- Used `.nullify` delete rules on both sides of Book-Shelf many-to-many relationship per research (cascade on many-to-many would delete books when a shelf is deleted)
- Default relationship arrays to `[]` to work around iOS 17.0 alphabetical ordering bug
- Post-fetch sorting via computed properties rather than dynamic @Query sort descriptors (simpler, works reliably per research recommendation)
- Progress computed at display time from chapterIndex/wordIndex/chapter.wordCount rather than stored in model (avoids sync issues, matches existing ReadingPositionService pattern)
- Updated all typealiases (Book, Chapter, ReadingPosition) to SchemaV2 since V2 is now the active schema
- Default sort option set to `.dateAdded` (preserves existing behavior where newest imports appear first)
- Shelf @Query added to LibraryView proactively for Plan 02 readiness

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Updated Chapter and ReadingPosition typealiases to SchemaV2**
- **Found during:** Task 1 (SchemaV2 creation)
- **Issue:** Plan only mentioned updating Book.swift typealias, but Chapter and ReadingPosition typealiases also need to point to SchemaV2 since the active schema is V2 and the relationships reference SchemaV2 types
- **Fix:** Updated Chapter.swift and ReadingPosition.swift typealiases to SchemaV2.Chapter and SchemaV2.ReadingPosition
- **Files modified:** BlazeBooks/Models/Chapter.swift, BlazeBooks/Models/ReadingPosition.swift
- **Verification:** Build succeeds with zero errors
- **Committed in:** d9d7591 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for correctness -- typealiases must all point to the same schema version for type consistency. No scope creep.

## Issues Encountered
None -- both tasks compiled and verified on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- SchemaV2 with Shelf model ready for Plan 02 shelf management features
- LibraryView has shelf @Query and MARK placeholder ready for shelf sections
- ContinueReadingSection is a reusable component that can be used as-is
- BookSortOption enum can be extended if needed

## Self-Check: PASSED

All 3 created files verified on disk. Both task commits (d9d7591, 48d5ae0) verified in git history. Clean build succeeds with zero errors.

---
*Phase: 05-library*
*Completed: 2026-02-21*
