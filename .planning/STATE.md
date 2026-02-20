# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** Synchronized reading and listening -- the voice tracks the displayed word perfectly, whether in RSVP or page mode
**Current focus:** Phase 1: Foundation

## Current Position

Phase: 2 of 7 (Reading Engine)
Plan: 0 of 3 in current phase
Status: Phase 1 Complete -- Ready for Phase 2
Last activity: 2026-02-20 -- Completed 01-03-PLAN.md (UI views and end-to-end wiring)

Progress: [██░░░░░░░░] 20%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: ~8 min
- Total execution time: ~0.4 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Foundation | 3 | ~24 min | ~8 min |

**Recent Trend:**
- Last 5 plans: 7m, 5m, multi-session
- Trend: --

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: 7 phases derived from 27 requirements, following EPUB -> Engine -> UI -> Library -> Discovery -> Sync dependency chain
- [Roadmap]: Phase 2 builds engines (RSVP, TTS, coordinator) with READ-01 so core sync can be verified before UI phases
- [Roadmap]: Phase 5 (Library) depends on Phase 1 only, enabling parallel work with Phases 3-4
- [01-01]: Local-only ModelConfiguration for development; CloudKit database param deferred to Phase 7
- [01-01]: Chapter.text stores full plain text at import time for offline reading
- [01-01]: ReadingPosition.verificationSnippet for position resilience across tokenizer changes
- [01-01]: SHA256 file hash via CryptoKit for duplicate EPUB detection
- [01-02]: @ObservationIgnored with manual lazy init for Readium components (lazy var incompatible with @Observable)
- [01-02]: Two-tier text extraction: Readium Content API primary, raw HTML stripping fallback
- [01-02]: Failed chapters produce placeholder text with parseError flag, not crashes
- [01-02]: WordTokenizer pinned to NLLanguage.english for deterministic tokenization
- [01-02]: EPUBImportService is @MainActor (UI state); EPUBParserService is not (async parsing)
- [01-03]: Used readingOrder instead of tableOfContents for chapter text extraction -- readingOrder is the content spine
- [01-03]: ScrollView .id(chapterIndex) forces complete rebuild on chapter navigation (SwiftUI caching workaround)
- [01-03]: Strip <head> blocks and heading tags from HTML before text extraction for clean chapter content
- [01-03]: Deterministic placeholder cover colors from DJB2 hash of book title
- [01-03]: ReadingPositionService debounces saves to 2-second intervals to avoid excessive SwiftData writes

### Pending Todos

None yet.

### Blockers/Concerns

- [Research]: AVSpeechSynthesizer silently cancels long utterances -- sentence-level chunking mandatory in Phase 2
- [Research]: CloudKit schema is permanent once deployed to production -- must get data model right in Phase 1
- [Research]: WPM-to-TTS rate calibration is nonlinear and voice-dependent -- requires empirical testing in Phase 2

## Session Continuity

Last session: 2026-02-20
Stopped at: Completed 01-03-PLAN.md -- Phase 1 Foundation complete
Resume file: None
