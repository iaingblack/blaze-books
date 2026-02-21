# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** Synchronized reading and listening -- the voice tracks the displayed word perfectly, whether in RSVP or page mode
**Current focus:** Phase 6: Book Discovery

## Current Position

Phase: 6 of 7 (Book Discovery) -- Gap closure complete
Plan: 4 of 4 in current phase
Status: Phase 6 Complete (including gap closure + performance fix)
Last activity: 2026-02-21 -- Completed 06-04-PLAN.md (Genre browsing performance)

Progress: [████████████████░░░░] 84%

## Performance Metrics

**Velocity:**
- Total plans completed: 16
- Average duration: ~5 min
- Total execution time: ~1.25 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Foundation | 3 | ~24 min | ~8 min |
| 2. Reading Engine | 3 | multi-session | varies |
| 3. Reading Experience | 2/2 | 12 min | 6 min |
| 4. Navigation & Appearance | 2/2 | 8 min | 4 min |
| 5. Library | 2/2 | 8 min | 4 min |
| 6. Book Discovery | 4/4 | 12 min | 3 min |

**Recent Trend:**
- Last 5 plans: 5m, 3m, 5m, 2m, 2m
- Trend: non-checkpoint plans complete quickly

*Updated after each plan completion*
| Phase 06 P02 | 5min | 2 tasks | 9 files |
| Phase 06 P03 | 2min | 2 tasks | 2 files |
| Phase 06 P04 | 2min | 2 tasks | 3 files |

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
- [02-01]: ORP lookup table from speedread: length 1-2 -> 0, 3-6 -> 1, 7-10 -> 2, 11-13 -> 3, 14+ -> 4
- [02-01]: Resume backs up 4 words before pause point (CONTEXT.md 3-5 range)
- [02-01]: TTSService recreates AVSpeechSynthesizer per chapter/start, nils after stop (iOS 17+ reliability)
- [02-01]: Sentence word counting via NLTokenizer(unit: .word) for consistency with WordTokenizer
- [02-01]: usesApplicationAudioSession = false per WWDC 2020 -- system manages audio session
- [02-01]: NSObject delegate bridge pattern: inner DelegateHandler forwards AVSpeechSynthesizerDelegate to @Observable
- [02-02]: withObservationTracking recursive pattern for RSVPEngine -> ReadingCoordinator state bridge in Timer mode
- [02-02]: 1.5-second chapter auto-advance delay via Task.sleep (Claude's discretion for chapter transitions)
- [02-02]: WPM-to-rate linear interpolation: rate 0.5 = 180 WPM baseline (approximate, empirical refinement needed)
- [02-02]: Conservative per-voice speed caps: 300 WPM default, 350 enhanced, 400 premium quality
- [02-02]: Download guidance card for voice downloads (Apple provides no API for uninstalled voices)
- [02-02]: Voice preview sample: "The quick brown fox jumps over the lazy dog."
- [02-03]: White foreground for RSVP before/after ORP text on dark background (.primary was invisible on black)
- [02-03]: GeometryReader with half-width frames for ORP character centering at exact screen midpoint
- [02-03]: Segmented Picker for Page/RSVP mode switching in reading view
- [03-01]: ReadingMode defaults to .rsvp (preserves existing behavior as primary mode)
- [03-01]: PageTextService is a struct (stateless service like WordTokenizer, not @Observable)
- [03-01]: ParagraphData caches WordTokens at split time to avoid re-tokenization per word highlight change
- [03-01]: highlightedWordIndex returns nil when paused (no frozen highlight in page mode)
- [03-01]: setWPM only updates RSVPEngine; commitWPMChange debounces TTS restart to slider drag end
- [03-02]: Animation suppressed on word highlight transitions via .transaction for instant swap (Research anti-pattern)
- [03-02]: WPMSliderView extracted as shared component used in both RSVP and page modes
- [03-02]: switchMode guard removed to support Picker binding (guard incompatible with SwiftUI state flow)
- [03-02]: coordinator.loadBook called on initial view appear for both modes (not just RSVP entry)
- [04-01]: ChapterRow value type mapping to avoid SwiftData @Model Binding interference in ForEach (Xcode 26 SDK)
- [04-01]: jumpToChapter extracted as shared method used by both TOC selection and prev/next buttons
- [04-02]: ReadingDefaults enum centralizes @AppStorage key and range constants to prevent default mismatches across views
- [04-02]: Line spacing uses 41% ratio (readingFontSize * 0.41) preserving original 7/17 design proportion
- [04-02]: RSVP dark theme is intentional design, not a dark mode bug -- documented in RSVPDisplayView
- [04-02]: Idle state dash uses .white.opacity(0.3) instead of .secondary for consistent contrast on dark RSVP background
- [Phase 05]: .nullify delete rules on both sides of Book-Shelf many-to-many to prevent cascade deletion of books
- [Phase 05]: Post-fetch sorting via computed properties instead of dynamic @Query sort descriptors
- [Phase 05]: Progress computed at display time from chapterIndex/wordIndex/chapter.wordCount (not stored in model)
- [05-02]: LibraryService as stateless struct with static methods (matches WordTokenizer pattern)
- [05-02]: ViewModifier pattern (BookContextMenuModifier) for conditional context menu based on onDelete presence
- [05-02]: Callback closures from ShelfSectionView to LibraryView for all management actions
- [05-02]: Shelf expansion state keyed by UUID dictionary to survive SwiftUI re-renders (Pitfall 4)
- [06-01]: gutenbergId: Int? on Book model for precise In Library detection (vs title-matching)
- [06-01]: 5-minute in-memory cache TTL to stay within Gutendex rate limits
- [06-01]: 14 genres with topic-based Gutendex API queries (Fiction, Sci-Fi, Mystery, Adventure, Romance, Horror, Philosophy, Poetry, History, Biography, Science, Children's, Short Stories, Drama)
- [06-02]: EPUBImportService refactored with importLocalEPUB shared method for both file-picker and download flows
- [06-02]: ImportError enum (alreadyInLibrary, parseFailed) for structured error handling across import paths
- [06-02]: BookDownloadService treats alreadyInLibrary as .completed (not error) for UX consistency
- [06-02]: Genre cover collages fetched in batches of 4 via TaskGroup to respect Gutendex rate limits
- [06-02]: Globe toolbar button in LibraryView for Discovery navigation
- [06-03]: CancellationError returns nil without setting self.error to avoid polluting error state during navigation transitions
- [06-03]: Task.isCancelled check leaves isInitialLoad=true so SwiftUI .task re-invocation auto-retries
- [06-04]: Removed all API preloading from DiscoveryView -- genre cards render instantly with fallback gradients (no network dependency)
- [06-04]: Moved EPUB filtering from server-side (mime_type param) to client-side (epubURL != nil) for ~2x API speed improvement
- [06-04]: 30-second URLSession timeout instead of 60-second default for fail-fast behavior on slow Gutendex API

### Pending Todos

None yet.

### Blockers/Concerns

- [Research]: AVSpeechSynthesizer silently cancels long utterances -- RESOLVED: sentence-level chunking implemented in 02-01 TTSService
- [Research]: CloudKit schema is permanent once deployed to production -- must get data model right in Phase 1
- [Research]: WPM-to-TTS rate calibration is nonlinear and voice-dependent -- requires empirical testing in Phase 2

## Session Continuity

Last session: 2026-02-21
Stopped at: Completed 06-04-PLAN.md (Genre browsing performance fix -- Phase 6 gap closure fully complete)
Resume file: .planning/phases/06-book-discovery/06-04-SUMMARY.md
