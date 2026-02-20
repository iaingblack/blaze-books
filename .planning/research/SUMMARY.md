# Project Research Summary

**Project:** Blaze Books
**Domain:** iOS RSVP ebook reader with synchronized text-to-speech
**Researched:** 2026-02-20
**Confidence:** HIGH

## Executive Summary

Blaze Books is an iOS reading app that occupies a genuine gap in the market: no iOS app currently combines Rapid Serial Visual Presentation (RSVP) speed reading with synchronized text-to-speech audio. The two categories — RSVP speed readers (Outread, Glance, RSVP Reader) and TTS audiobook readers (Voice Dream, Speechify) — exist as completely separate camps. Blaze Books sits at their intersection, and the only prior attempt at this combination (Reedy) is Android/Chrome-only and lacks tight synchronization. The stack is well-defined by project constraints: Swift 6, SwiftUI, SwiftData, AVFoundation, and the Readium Swift Toolkit for EPUB handling. This is a cohesive Apple-first stack with no unnecessary third-party dependencies.

The recommended build approach centers on a `ReadingCoordinator` that mediates between an independent `RSVPEngine` (timer-driven word display) and `TTSService` (AVSpeechSynthesizer callbacks). The critical architectural insight is that in synchronized mode, TTS word-boundary callbacks must serve as the clock source — not a parallel timer — to prevent audio/visual drift. The `(chapterIndex, wordIndex)` tuple is the universal position primitive throughout the entire system, bridging RSVP display, TTS character ranges, persistence, and iCloud sync. EPUB parsing via Readium provides both the content extraction and a built-in TTS orchestration layer (`PublicationSpeechSynthesizer`), substantially reducing custom synchronization code.

The primary risks are technical rather than product: AVSpeechSynthesizer has documented bugs where long utterances silently cancel mid-chapter, and its `willSpeakRange` callbacks drift over time. Both are mitigated by the same architectural decision — sentence-level utterance chunking with independent word-index tracking. The SwiftData + CloudKit layer carries irreversible schema constraints that must be designed correctly before the first App Store release; retrofitting is costly and some mistakes are permanent. The EPUB parser must be battle-tested against diverse real-world files (10-20% of Project Gutenberg EPUBs contain malformed XML) before any reading functionality is built on top of it.

## Key Findings

### Recommended Stack

The entire stack is first-party Apple frameworks plus one well-maintained open-source library. Swift 6 with SwiftUI and SwiftData satisfies the project constraints, and iOS 17 as the minimum deployment target unlocks all required APIs. The Readium Swift Toolkit (3.6.0, released January 2026) is the correct EPUB library: it provides text extraction, chapter navigation, TTS orchestration, word-level tokenization, and decoration overlays — solving the hardest parts of the sync problem directly. No alternative comes close for this use case. AVSpeechSynthesizer handles on-device TTS with zero cost and no network dependency. Gutendex provides free, auth-free REST access to Project Gutenberg's catalog.

**Core technologies:**
- **Swift 6 + SwiftUI (iOS 17+):** Language and UI framework — project constraint, required for async/await and SwiftData integration
- **Readium Swift Toolkit 3.6.0:** EPUB parsing, text extraction, TTS orchestration, word-level tokenization, decoration highlighting — single SPM dependency that solves the synchronization problem
- **AVFoundation / AVSpeechSynthesizer:** On-device TTS with word-boundary delegate callbacks — no cost, no network, no subscription
- **SwiftData + CloudKit:** Persistence and iCloud sync — one-line configuration, but carries strict schema constraints that are permanent once deployed to production
- **Gutendex API:** REST API for Project Gutenberg book metadata and EPUB download URLs — free, no auth, supports search and language filtering
- **URLSession:** Networking for Gutendex — no third-party HTTP library needed for simple REST

### Expected Features

**Must have (table stakes):**
- EPUB import (Files app integration) — zero content without it, every ebook reader has this
- Reading position persistence (per-book) — losing your place is a deal-breaker
- Adjustable WPM speed (100-500 range) — core to any RSVP app, users expect granular control
- Basic library view with covers and titles — users need to find their books
- Table of contents navigation — users expect chapter-jump in any EPUB reader
- Dark mode and font size controls — accessibility fundamentals, expected by default
- Offline reading — books are local files; must work without internet
- Both reading modes: RSVP (single word) and Page (full text with highlight)
- Bookmarks — standard in all reading apps

**Should have (competitive differentiators):**
- Synchronized TTS + RSVP — the primary differentiator; no iOS app does this
- Voice speed cap with graceful degradation — better UX than competitors who produce garbled audio at high speeds
- Seamless dual-mode switching without position loss — shares position model between modes
- Curated Project Gutenberg collections — free book discovery built in; no competitor integrates this
- Apple voice selection with download guidance — no subscription cost, improves with each iOS release
- iCloud sync (library, positions) — multi-device Apple users expect this

**Defer (v2+):**
- In-app Gutenberg search — curated lists serve v1; full search is a large feature
- Reading statistics and gamification — defer until core experience is validated
- Annotations in page mode — conflicts with RSVP metaphor, complex data model
- AI voices (ElevenLabs, Azure, Google) — costly, network-dependent, subscription pressure; Apple voices are sufficient

### Architecture Approach

The architecture follows a layered service pattern: a Presentation Layer (SwiftUI views grouped by feature), a Service Layer (independent `@Observable` classes injected via environment), and a Data Layer (SwiftData models with CloudKit sync). The `ReadingCoordinator` is the architectural keystone — a mediator that owns the relationship between `RSVPEngine` and `TTSService` so neither service knows about the other. This enables running either mode independently and makes the synchronization logic testable in isolation. All components reference position as `(chapterIndex, wordIndex)`, which is the stable, mode-agnostic primitive that bridges display, audio, persistence, and sync.

**Major components:**
1. **EPUBService** — EPUB parsing and text extraction using Readium, produces `Chapter` structs with plain text
2. **WordTokenizer** — deterministic text-to-indexed-token splitting, produces `[WordToken]` with sentence boundary flags; must be locked down early since changes invalidate saved positions
3. **RSVPEngine** — timer-driven `@Observable` class that advances `currentWord` at WPM-derived intervals; timer-only in RSVP-only mode, slaved to TTS in synchronized mode
4. **TTSService** — wraps `AVSpeechSynthesizer`; speaks sentence-level utterance chunks, converts `willSpeakRange` callbacks to word-index events, reports to coordinator
5. **ReadingCoordinator** — mediates RSVPEngine and TTSService; in synchronized mode, TTS callbacks are the clock source; arbitrates conflicts, handles pause/resume, saves position
6. **LibraryManager** — thin SwiftData wrapper for book CRUD, import, shelf management
7. **GutenbergService** — Gutendex API calls and EPUB download, independent of reading modes
8. **SwiftData Models** — `Book`, `Shelf`, `ReadingPosition`, `VoicePreference`; all properties optional or defaulted, no unique constraints, all relationships optional (CloudKit requirements)

### Critical Pitfalls

1. **AVSpeechSynthesizer silently cancels long utterances** — Never pass an entire chapter as a single utterance. Use sentence-level chunking from the start. Store the synthesizer as an instance property (not local variable). Test every supported voice with 5000+ word chapters.

2. **Word-voice sync drift grows over an utterance** — `willSpeakRange` callbacks accumulate offset errors, especially with Unicode, punctuation, and certain voice engines. Maintain your own word-index array and treat TTS callbacks as hints that snap to the nearest expected word. Use sentence boundaries as sync checkpoints.

3. **CloudKit schema is permanent once deployed to production** — Design models conservatively before any App Store release: all properties optional or defaulted, all relationships optional, no `@Attribute(.unique)`, ship with `VersionedSchema`. A wrong field is permanent; a rename is treated as delete + add (data loss).

4. **CloudKit sync silently fails in production builds** — Debug builds use the development CloudKit environment; TestFlight and App Store builds use production. If you never deployed your schema to production via the CloudKit Dashboard, sync produces no errors but does nothing. Verify in TestFlight before any public release.

5. **EPUB parser fails on 10-20% of real-world files** — Gutenberg EPUBs use HTML entities (`&nbsp;`, `&mdash;`) that are illegal in XHTML. Test against 50+ real Project Gutenberg EPUBs. Pre-process content to resolve HTML entities. Implement a fallback text-extraction pipeline.

## Implications for Roadmap

Based on research, the dependency chain is clear: EPUB parsing is the foundation for everything, the synchronization architecture must be designed before any reading UI is built, CloudKit model constraints must be respected from day one, and Gutenberg integration is independent and can be added after the core reading loop works.

### Phase 1: Foundation — Data Models, EPUB Parsing, and Word Tokenization

**Rationale:** Everything depends on getting clean, tokenized text out of EPUB files with a stable `(chapterIndex, wordIndex)` position model. CloudKit schema constraints are permanent once deployed — the data model must be correct before any persistence code is written. The `WordTokenizer` output format must be locked down before either `RSVPEngine` or `TTSService` is built, since both consume it.

**Delivers:** Parseable EPUB library, stable word-index position model, CloudKit-compatible SwiftData schema, file import from Files app.

**Addresses:** EPUB import, reading position persistence, table of contents structure.

**Avoids:**
- CloudKit schema lock-in (Pitfall 3) — design all models with optional properties, no unique constraints, VersionedSchema from day one
- EPUB parsing failures (Pitfall 5) — test against 50+ Gutenberg EPUBs before any reading feature is built on top
- Character-offset position anti-pattern — use `(chapterIndex, wordIndex)` from the start

### Phase 2: Core Reading Loop — RSVPEngine, TTSService, and ReadingCoordinator

**Rationale:** This is the technical heart of the app and the primary differentiator. `RSVPEngine` and `TTSService` can be developed and tested independently, then wired together through the `ReadingCoordinator`. AVSpeechSynthesizer bugs must be discovered and mitigated here, not discovered after the UI is built. In synchronized mode, TTS must be the clock source, not a parallel timer.

**Delivers:** Working RSVP display at configurable WPM, working TTS audio with word-boundary callbacks, synchronized coordinator that keeps visual display locked to audio position, voice speed cap logic.

**Addresses:** RSVP reading mode, TTS synchronization (primary differentiator), voice selection, voice speed cap.

**Avoids:**
- AVSpeechSynthesizer truncation (Pitfall 1) — sentence-level utterance chunking is mandatory; never pass full chapters
- Word-voice sync drift (Pitfall 2) — independent word-index tracking with TTS callbacks as hints, sentence-boundary checkpoints
- Bidirectional coupling anti-pattern — coordinator mediates, RSVP and TTS are unaware of each other
- Main-thread EPUB parsing anti-pattern — all parsing on background Task

### Phase 3: Reading UI — RSVP View, Page Mode, and Reading Controls

**Rationale:** UI is last because it trivially consumes the services built in Phase 2. Building views before services leads to ViewModel sprawl and makes service testing harder. Both reading modes share the same coordinator and position model, so mode switching is a view concern, not a data concern.

**Delivers:** RSVP word display with ORP highlighting, full-page mode with word-by-word highlight during TTS, reading controls (WPM slider, play/pause, chapter nav), table of contents view, seamless mode switching without position loss.

**Addresses:** Page reading mode, dual-mode switching, table of contents navigation, bookmarks, dark mode, font size.

**Avoids:**
- Jarring mode transitions — scroll to and highlight exact current word when switching from RSVP to page mode
- No progress feedback in RSVP — always show chapter name, percentage, time remaining
- No variable timing — implement pause-on-punctuation and word-length scaling before user testing

### Phase 4: Library and Book Management

**Rationale:** Library features are important but do not block the core reading experience. Once reading works, library views consume the same `LibraryManager` service and are straightforward SwiftUI. An empty first-launch state must be avoided to prevent App Store Guideline 4.2 rejection.

**Delivers:** Library grid/list with cover art, book detail view, shelf organization, "continue reading" section, book import flow, pre-loaded Gutenberg books for first launch.

**Addresses:** Basic library view, shelves/organization, offline support, first-launch empty state.

**Avoids:**
- App Store Guideline 4.2 rejection (empty state) — ship with 5-10 pre-loaded Gutenberg books or a compelling onboarding flow

### Phase 5: Gutenberg Integration

**Rationale:** Gutenberg integration is independent of the reading stack — it feeds the library but has no reading-mode dependencies. It can be built in parallel with Phase 3-4 if resourcing allows, or after core reading is working. Curated lists for v1 (not full search) keeps scope contained.

**Delivers:** Curated Gutenberg collections by genre/popularity, EPUB download and import into library, Gutendex API integration with caching.

**Addresses:** Curated Gutenberg collections (competitive differentiator), free book discovery without leaving the app.

**Avoids:**
- Full search scope creep — curated lists only for v1; link to gutenberg.org for full catalog

### Phase 6: iCloud Sync and Polish

**Rationale:** CloudKit sync layered onto already-correct local persistence. The data model was designed for CloudKit in Phase 1; enabling sync is a configuration change. However, production CloudKit testing requires physical devices and a TestFlight build, so this is verified last before App Store submission.

**Delivers:** Cross-device library sync, reading position sync, production CloudKit schema deployment.

**Addresses:** iCloud sync (library, positions, shelves).

**Avoids:**
- Silent sync failure in production (Pitfall 4) — verify end-to-end in TestFlight between two real devices; deploy schema to production CloudKit Dashboard before any public release

### Phase Ordering Rationale

- Foundation before reading modes because `WordTokenizer` output is consumed by both `RSVPEngine` and `TTSService`, and the data model must be CloudKit-compatible from the start.
- Reading modes before UI because services must be testable independently, and the synchronization architecture is the hardest problem — it should be solved before views are added.
- Library after reading because users who can read need a library; users who have a library but cannot read have nothing.
- Gutenberg after core reading because it feeds the library but does not affect the reading experience itself.
- iCloud sync last because it builds on correct local persistence and requires production CloudKit testing in TestFlight before release.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (ReadingCoordinator):** The TTS-as-clock-source synchronization pattern has no reference implementation. The WPM-to-AVSpeechUtterance.rate mapping is nonlinear and voice-dependent — requires empirical calibration during development.
- **Phase 2 (AVSpeechSynthesizer background audio):** Background TTS requires a workaround (silent AVAudioPlayer to keep audio session active). The exact implementation pattern needs verification.
- **Phase 6 (CloudKit production):** Production CloudKit testing cannot be done until TestFlight. Schema deployment sequence requires careful step-by-step verification.

Phases with standard patterns (research not required):
- **Phase 1 (SwiftData models):** CloudKit constraints are fully documented. Pattern is: all optional, VersionedSchema, no unique.
- **Phase 3 (RSVP display):** Timer-driven single-word display with opacity transitions is a known SwiftUI pattern. ORP coloring via `AttributedString` is straightforward.
- **Phase 4 (Library views):** Standard SwiftUI grid/list patterns with SwiftData `@Query`. Well-documented.
- **Phase 5 (Gutendex API):** Simple REST API with documented JSON schema. URLSession with async/await. No research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies are first-party Apple frameworks or verified via Context7 (Readium benchmark 86.7, High reputation). The only uncertainty is the empirical WPM-to-AVSpeechUtterance.rate mapping, which requires device testing. |
| Features | MEDIUM | Competitive analysis covers 15+ apps. No direct competitor combines RSVP + TTS on iOS, which validates the gap but also means less direct comparison data. Feature prioritization is based on patterns from adjacent apps. |
| Architecture | HIGH | `ReadingCoordinator` mediator pattern is standard for multi-source synchronization. The `(chapterIndex, wordIndex)` position model is clearly the right abstraction. Build order follows direct dependency analysis. |
| Pitfalls | HIGH | AVSpeechSynthesizer truncation and sync drift are verified against Apple Developer Forums with active bug reports. CloudKit constraints verified against Apple docs and fatbobman.com. EPUB parsing failures verified against EpubReader malformed EPUB documentation. |

**Overall confidence:** HIGH

### Gaps to Address

- **WPM-to-TTS rate calibration:** The relationship between user-visible WPM slider values and `AVSpeechUtterance.rate` floats is nonlinear and voice-dependent. There is no Apple API to query this mapping. Empirical calibration with target voices is required during Phase 2 development. Plan for a calibration test harness early.

- **RSVP timer accuracy at high WPM:** SwiftUI `Timer.publish` may produce visible jitter at 400-500 WPM (each word displays for 120-150ms). Research suggests `CADisplayLink` for display-synchronized updates, but this has not been verified against this specific use case. Plan to profile with Instruments during Phase 2 and replace the timer if needed.

- **Voice pack download UX:** Apple does not expose a programmatic API to trigger enhanced voice downloads. The only path is directing users to Settings > Accessibility > Spoken Content > Voices. The UX for this needs design consideration during Phase 3/4.

- **EPUB file sync across devices:** The CloudKit sync will sync book metadata and positions, but not the EPUB file itself (too large for CloudKit private database). Other devices will see book records but need to re-import the file. This "metadata without content" state needs a clear UX treatment.

## Sources

### Primary (HIGH confidence)
- `/readium/swift-toolkit` (Context7, benchmark 86.7) — EPUB parsing, text extraction, `PublicationSpeechSynthesizer`, word tokenization, `DecorableNavigator`, voice utilities
- `/websites/developer_apple_swiftdata` (Context7, benchmark 76.3) — SwiftData CloudKit configuration, `ModelConfiguration`, `initializeCloudKitSchema`, `VersionedSchema`
- `/websites/developer_apple_swiftui` (Context7, benchmark 87.3) — `ContentTransition`, `@Observable`, environment injection
- [Apple AVSpeechSynthesizer documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) — rate constants, delegate callbacks, voice management
- [Apple SwiftData + CloudKit documentation](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) — sync setup, constraints

### Secondary (MEDIUM confidence)
- [fatbobman.com: Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — schema migration constraints, CloudKit rules
- [fatbobman.com: Designing Models for CloudKit Sync](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) — add-only schema migration, optional properties
- [Hacking with Swift: AVSpeechSynthesizer word highlighting](https://www.hackingwithswift.com/example-code/media/how-to-highlight-text-to-speech-words-being-read-using-avspeechsynthesizer) — `willSpeakRangeOfSpeechString` delegate pattern
- [Apple Developer Forums: AVSpeechSynthesizer broken on iOS 17](https://developer.apple.com/forums/thread/737685) — confirmed truncation bug, no workaround from Apple
- [EpubReader: Handling Malformed EPUB files](https://os.vers.one/EpubReader/malformed-epub/index.html) — XHTML entity parsing issues
- [Gutendex API documentation](https://gutendex.com/) — endpoint parameters, response schema, EPUB URL structure

### Tertiary (MEDIUM-LOW confidence)
- Competitive analysis of Outread, Glance, Voice Dream, Speechify, RSVP Reader, Readly, Reedy — market positioning, feature gaps
- [Swift Forums: SwiftUI high-frequency updates](https://forums.swift.org/t/how-to-update-swiftui-many-times-a-second-while-being-performant/71249) — `Timer.publish` viability at high WPM (needs device validation)
- [AzamSharp: If You Are Not Versioning Your SwiftData Schema](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html) — `VersionedSchema` importance (recent, 2026)

---
*Research completed: 2026-02-20*
*Ready for roadmap: yes*
