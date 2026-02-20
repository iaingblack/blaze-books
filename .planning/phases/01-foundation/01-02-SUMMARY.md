---
phase: 01-foundation
plan: 02
subsystem: epub-pipeline
tags: [readium, epub, nltokenizer, swiftdata, import, parsing, tokenization, ios]

# Dependency graph
requires:
  - phase: 01-foundation-01
    provides: "Xcode project with Readium SPM, SwiftData models (Book, Chapter, ReadingPosition), FileStorageManager"
provides:
  - "EPUBImportService: security-scoped file import, sandbox copy, duplicate detection, SwiftData persistence"
  - "EPUBParserService: Readium-based EPUB opening, metadata extraction, chapter text extraction with fallbacks"
  - "WordTokenizer: NLTokenizer-based word/sentence tokenization with verification snippets"
  - "Complete import-parse-tokenize pipeline from file URL to persisted SwiftData records"
affects: [01-03, phase-2, phase-3, phase-5]

# Tech tracking
tech-stack:
  added: [NaturalLanguage (NLTokenizer)]
  patterns: [ObservationIgnored for lazy Readium components, two-tier text extraction (Content API + HTML fallback), two-pass tokenization (sentence + word)]

key-files:
  created:
    - BlazeBooks/Services/EPUBImportService.swift
    - BlazeBooks/Services/EPUBParserService.swift
    - BlazeBooks/Services/WordTokenizer.swift
  modified: []

key-decisions:
  - "Used @ObservationIgnored with manual lazy initialization for Readium components (lazy var incompatible with @Observable macro)"
  - "Two-tier chapter text extraction: Readium Content API primary, raw HTML stripping fallback for resilience"
  - "Failed chapters produce placeholder text with parseError flag rather than crashing the import"
  - "WordTokenizer pinned to NLLanguage.english for deterministic tokenization across runs"
  - "EPUBParserService is not @MainActor (parsing runs async); EPUBImportService is @MainActor (drives UI state)"

patterns-established:
  - "Import pipeline: EPUBImportService -> EPUBParserService -> WordTokenizer chain"
  - "Duplicate detection: SHA256 hash query via FetchDescriptor before creating records"
  - "Smart metadata fallbacks: missing title -> filename, missing author -> 'Unknown Author', missing cover -> nil"
  - "Chapter resilience: broken chapters imported with placeholder text, not skipped"

requirements-completed: [EPUB-01, EPUB-02, EPUB-03]

# Metrics
duration: 5min
completed: 2026-02-20
---

# Phase 1 Plan 02: EPUB Import Pipeline Summary

**Import-parse-tokenize pipeline using Readium Swift Toolkit, NLTokenizer word/sentence tokenization, and SwiftData persistence with duplicate detection and chapter-level error resilience**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-20T15:53:20Z
- **Completed:** 2026-02-20T15:59:11Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Complete EPUB import pipeline from file picker URL to persisted SwiftData records (Book, Chapter, ReadingPosition)
- Security-scoped URL handling with file copy to Documents/Books/ sandbox and SHA256 duplicate detection
- Readium-based EPUB parsing with metadata extraction (title, author, cover) and smart fallbacks
- Two-tier chapter text extraction: Readium Content API primary path with raw HTML stripping fallback
- NLTokenizer-based word tokenization with sentence boundary detection (pinned to English for determinism)
- Resilient chapter handling: broken chapters get placeholder text instead of crashing the import

## Task Commits

Each task was committed atomically:

1. **Task 1: Create EPUBImportService with file handling and duplicate detection** - `af4ffd1` (feat)
2. **Task 2: Create EPUBParserService and WordTokenizer** - `a3043fc` (feat)

## Files Created/Modified
- `BlazeBooks/Services/EPUBImportService.swift` - @MainActor @Observable service handling security-scoped import, sandbox copy, duplicate detection, Readium parsing, and SwiftData record creation
- `BlazeBooks/Services/EPUBParserService.swift` - @Observable service wrapping Readium for EPUB opening, metadata extraction, chapter text extraction with Content API + HTML fallback, and tokenization
- `BlazeBooks/Services/WordTokenizer.swift` - Stateless struct using NLTokenizer for word/sentence tokenization with verification snippet generation

## Decisions Made
- Used `@ObservationIgnored` with manual lazy initialization pattern for Readium components (`DefaultHTTPClient`, `AssetRetriever`, `PublicationOpener`) because Swift's `lazy var` is incompatible with `@Observable` macro (macro converts stored properties to computed properties).
- Implemented two-tier chapter text extraction: Readium Content API as primary path (uses `publication.content(from: locator).text()`), with raw HTML stripping as fallback for chapters where the Content API returns empty text.
- Failed chapters produce placeholder text ("This chapter could not be displayed") with `parseError: true` flag, rather than skipping or crashing. This allows partial book import per CONTEXT.md locked decision.
- WordTokenizer pinned to `NLLanguage.english` for deterministic tokenization. Multi-language support deferred to future phases.
- EPUBImportService marked `@MainActor` since it drives UI state. EPUBParserService is not `@MainActor` -- parsing runs in async context but UI state updates happen via `@Observable` property changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed lazy var incompatibility with @Observable macro**
- **Found during:** Task 2 (EPUBParserService implementation)
- **Issue:** Swift's `lazy var` is incompatible with `@Observable` macro -- the macro converts stored properties to computed properties, causing compilation errors
- **Fix:** Replaced `lazy var` with `@ObservationIgnored` optional backing properties and manual lazy-initialization computed properties
- **Files modified:** BlazeBooks/Services/EPUBParserService.swift
- **Verification:** Build succeeds with zero errors
- **Committed in:** a3043fc (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary fix for @Observable compatibility. No scope creep.

## Issues Encountered
- `lazy var` properties cause compilation errors when used inside `@Observable` classes in Swift 5.10+. The `@Observable` macro transforms all non-ignored properties into computed properties backed by observation registrations, and `lazy` requires direct stored property semantics. Resolved by using `@ObservationIgnored` optional backing properties with manual initialization in computed property getters.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Import pipeline is complete: file URL -> sandbox copy -> Readium parse -> tokenize -> SwiftData persist
- Ready for Plan 03: Library grid view, import button with .fileImporter, reading view with position tracking
- WordTokenizer `verificationSnippet` method is ready for ReadingPositionService in future phases
- EPUBParserService `parseProgress` is observable for import progress UI

## Self-Check: PASSED

All 3 created files verified on disk. Both task commits (af4ffd1, a3043fc) verified in git history. Clean build succeeds with zero errors.

---
*Phase: 01-foundation*
*Completed: 2026-02-20*
