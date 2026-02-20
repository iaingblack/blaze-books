---
phase: 01-foundation
plan: 03
subsystem: ui-views
tags: [swiftui, lazyvgrid, scrollview, reading-position, navigation, swiftdata, epub, ios]

# Dependency graph
requires:
  - phase: 01-foundation-02
    provides: "EPUBImportService, EPUBParserService, WordTokenizer, complete import pipeline"
provides:
  - "LibraryView: cover-forward grid layout with LazyVGrid, empty state, import button in toolbar"
  - "BookCoverView: cover image display with generated color placeholders from title hash"
  - "ImportButton: .fileImporter trigger for EPUB selection with inline progress"
  - "ReadingView: scrollable chapter text with paragraph IDs, chapter navigation, progress bar"
  - "ReadingPositionService: debounced auto-save of scroll position to SwiftData with restore"
  - "ContentView: NavigationStack root wiring library and reading views"
  - "End-to-end flow: import EPUB -> library grid -> tap to read -> position auto-saves"
affects: [phase-2, phase-3, phase-4, phase-5]

# Tech tracking
tech-stack:
  added: []
  patterns: [cover-forward LazyVGrid library, deterministic color from string hash, GeometryReader scroll tracking with debounced save, ScrollViewReader position restore, readingOrder-based chapter text extraction]

key-files:
  created:
    - BlazeBooks/Views/Library/LibraryView.swift
    - BlazeBooks/Views/Library/BookCoverView.swift
    - BlazeBooks/Views/Import/ImportButton.swift
    - BlazeBooks/Views/Reading/ReadingView.swift
    - BlazeBooks/Services/ReadingPositionService.swift
  modified:
    - BlazeBooks/App/ContentView.swift
    - BlazeBooks/App/BlazeBooksApp.swift
    - BlazeBooks/Services/EPUBParserService.swift

key-decisions:
  - "Used readingOrder instead of tableOfContents for chapter text extraction -- readingOrder contains the actual content spine while TOC is navigational"
  - "ScrollView with .id(chapterIndex) to force complete rebuild on chapter navigation -- prevents stale text from prior chapter"
  - "Strip <head> blocks and heading tags from HTML before text extraction to avoid CSS/metadata leaking into chapter text"
  - "Deterministic placeholder cover colors derived from book title string hash for visual consistency"
  - "ReadingPositionService debounces saves to every 2 seconds to avoid excessive SwiftData writes during scrolling"

patterns-established:
  - "Library grid: LazyVGrid with adaptive columns (120pt min) for responsive cover layout"
  - "Cover-forward design: BookCoverView as reusable component with image or generated placeholder"
  - "Reading view: ScrollViewReader + GeometryReader for position tracking and restore"
  - "Chapter navigation: prev/next buttons updating @State text with ScrollView rebuild via .id()"

requirements-completed: [EPUB-01, EPUB-04, LIB-05]

# Metrics
duration: multi-session (Tasks 1-2 automated, Task 3 human-verified with 4 bug fixes)
completed: 2026-02-20
---

# Phase 1 Plan 03: UI Views and End-to-End Wiring Summary

**Library grid with cover-forward LazyVGrid, scrollable reading view with debounced position auto-save, and complete import-to-read flow verified end-to-end across 9 acceptance criteria**

## Performance

- **Duration:** Multi-session (automated tasks + human verification with bug fix cycle)
- **Started:** 2026-02-20 (continuation of earlier session)
- **Completed:** 2026-02-20T17:59:48Z
- **Tasks:** 3 (2 auto + 1 checkpoint, all complete)
- **Files modified:** 8

## Accomplishments
- Complete end-to-end import-to-read flow: Files picker -> EPUB parse -> library grid display -> tap to read -> position saves and restores
- Cover-forward library grid with LazyVGrid adaptive columns, generated color placeholders for books without covers, and inline import progress
- Scrollable reading view with chapter headers, readable typography, paragraph-based layout, prev/next chapter navigation, and thin progress bar
- ReadingPositionService with debounced auto-save (2-second interval) and ScrollViewReader-based position restore on reopen
- Human-verified against 9 acceptance criteria: empty state, import, reading, position tracking, chapter navigation, duplicate detection, offline, and multi-book

## Task Commits

Each task was committed atomically:

1. **Task 1: Create library grid view, book cover view, and import button** - `e0ab56e` (feat)
2. **Task 2: Create reading view with position tracking and progress bar** - `4cbf5f7` (feat)
3. **Task 3: Verify complete Phase 1 import-to-read flow** - no commit (checkpoint:human-verify, approved)

**Bug fix commits (between Task 2 and Task 3 approval):**
- `73f1b2a` - fix: use readingOrder for text extraction (empty chapter text)
- `98121a0` - fix: chapter text not updating on navigation
- `9969c54` - fix: force ScrollView rebuild on chapter navigation
- `ce1f4bc` - fix: strip head block and headings from extracted chapter text

**Xcode project update:** `ceaa16c` (chore: update Xcode project references after build)

## Files Created/Modified
- `BlazeBooks/Views/Library/LibraryView.swift` - LazyVGrid library with @Query-driven book display, empty state, toolbar import button, and NavigationLink to reading view
- `BlazeBooks/Views/Library/BookCoverView.swift` - Reusable book cover with UIImage rendering or deterministic color placeholder from title hash, 2:3 aspect ratio
- `BlazeBooks/Views/Import/ImportButton.swift` - Toolbar button triggering .fileImporter for EPUB selection, delegates to EPUBImportService
- `BlazeBooks/Views/Reading/ReadingView.swift` - Scrollable reading view with chapter text, paragraph IDs, GeometryReader scroll tracking, chapter navigation, and progress bar
- `BlazeBooks/Services/ReadingPositionService.swift` - @Observable position tracker with debounced SwiftData saves, chapter/book progress calculation, and position restore
- `BlazeBooks/App/ContentView.swift` - Updated to NavigationStack root with LibraryView
- `BlazeBooks/App/BlazeBooksApp.swift` - Environment object injection for EPUBImportService and EPUBParserService
- `BlazeBooks/Services/EPUBParserService.swift` - Modified to use readingOrder for chapter extraction, strip HTML head blocks and headings

## Decisions Made
- Used `publication.readingOrder` instead of `publication.tableOfContents` for chapter text extraction. The readingOrder contains the actual content spine (ordered list of resources the user reads through), while tableOfContents is a navigational structure that may not map 1:1 to content resources. This fixed empty chapter text.
- Force ScrollView rebuild via `.id(chapterIndex)` modifier when navigating chapters. Without this, SwiftUI reuses the existing ScrollView and does not update the displayed text. The `.id()` forces a complete teardown and rebuild.
- Strip `<head>` blocks and `<h1>`-`<h6>` tags from raw HTML before text extraction. The fallback HTML stripping path was including CSS rules and metadata from `<head>`, and heading content was duplicating the chapter title.
- Deterministic placeholder cover colors derived from DJB2 hash of the book title string, providing visual variety while keeping colors consistent across app sessions.
- ReadingPositionService debounces saves to every 2 seconds using a timestamp check to avoid excessive SwiftData writes during continuous scrolling.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed empty chapter text by switching to readingOrder**
- **Found during:** Post-Task 2 testing
- **Issue:** Chapters displayed no text because EPUBParserService used `tableOfContents` which returned navigational links, not content resources
- **Fix:** Changed to `publication.readingOrder` which contains the actual content spine with extractable text
- **Files modified:** BlazeBooks/Services/EPUBParserService.swift
- **Verification:** Chapters now display full text content
- **Committed in:** 73f1b2a

**2. [Rule 1 - Bug] Fixed chapter text not updating on navigation**
- **Found during:** Post-Task 2 testing
- **Issue:** Tapping next/previous chapter did not update the displayed text in ReadingView
- **Fix:** Corrected the @State text binding to update when chapter index changes
- **Files modified:** BlazeBooks/Views/Reading/ReadingView.swift
- **Verification:** Chapter navigation now displays correct chapter text
- **Committed in:** 98121a0

**3. [Rule 1 - Bug] Forced ScrollView rebuild on chapter navigation**
- **Found during:** Post-Task 2 testing
- **Issue:** Even after fixing the text binding, SwiftUI reused the existing ScrollView, showing stale content
- **Fix:** Added `.id(chapterIndex)` modifier to ScrollView to force complete rebuild on chapter change
- **Files modified:** BlazeBooks/Views/Reading/ReadingView.swift
- **Verification:** Chapter navigation now shows fresh content with scroll position reset to top
- **Committed in:** 9969c54

**4. [Rule 1 - Bug] Stripped head blocks and headings from extracted chapter text**
- **Found during:** Post-Task 2 testing
- **Issue:** HTML fallback text extraction included CSS from `<head>` tags and duplicated chapter titles from heading tags
- **Fix:** Added regex-based stripping of `<head>...</head>` blocks and `<h1>`-`<h6>` tags before text extraction
- **Files modified:** BlazeBooks/Services/EPUBParserService.swift (and possibly ReadingView.swift)
- **Verification:** Chapter text is clean without CSS artifacts or duplicated headings
- **Committed in:** ce1f4bc

---

**Total deviations:** 4 auto-fixed (4 bugs, all Rule 1)
**Impact on plan:** All fixes were necessary for correct chapter text display and navigation. No scope creep -- all bugs were in the core import-to-read pipeline.

## Issues Encountered
- EPUB `tableOfContents` vs `readingOrder` confusion: Readium's `tableOfContents` returns navigation structure (links), not the content spine. The `readingOrder` property contains the actual ordered list of resources with extractable text. This is a common Readium gotcha.
- SwiftUI ScrollView caching: SwiftUI aggressively reuses ScrollView instances even when the content changes. The `.id()` modifier is the standard workaround to force a fresh view.
- HTML fallback text extraction quality: Raw HTML stripping needs pre-processing to remove non-content elements (`<head>`, headings that duplicate chapter titles) before the general tag-stripping pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 1 is fully complete: data models, EPUB import pipeline, library UI, reading view, and position tracking all working end-to-end
- Ready for Phase 2 (Reading Engine): ReadingPositionService and WordTokenizer provide the foundation for RSVP and TTS synchronization
- The Chapter.text field contains clean, tokenized text ready for word-by-word RSVP display
- ReadingView provides the scaffold that will be extended with RSVP mode and TTS controls in Phase 3

## Self-Check: PASSED

All 5 created files verified on disk. All 7 commits (e0ab56e, 4cbf5f7, 73f1b2a, 98121a0, 9969c54, ce1f4bc, ceaa16c) verified in git history. SUMMARY.md created successfully.

---
*Phase: 01-foundation*
*Completed: 2026-02-20*
