# Architecture Research

**Domain:** iOS RSVP ebook reader with synchronized text-to-speech
**Researched:** 2026-02-20
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                         │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────┐   │
│  │  Library   │  │   RSVP    │  │   Page    │  │   Settings    │   │
│  │   Views    │  │   View    │  │   View    │  │    Views      │   │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └──────┬────────┘   │
│        │              │              │               │             │
├────────┴──────────────┴──────────────┴───────────────┴─────────────┤
│                         Service Layer                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  EPUB    │  │  RSVP    │  │   TTS    │  │    Gutenberg     │   │
│  │ Service  │  │  Engine  │  │ Service  │  │    Service       │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬──────────┘   │
│       │              │              │               │             │
│       │         ┌────┴──────────────┴────┐          │             │
│       │         │   ReadingCoordinator   │          │             │
│       │         └────────────────────────┘          │             │
├───────┴─────────────────────────────────────────────┴─────────────┤
│                         Data Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐   │
│  │  SwiftData   │  │   File       │  │   CloudKit Sync        │   │
│  │  Models      │  │   Storage    │  │   (via SwiftData)      │   │
│  └──────────────┘  └──────────────┘  └────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **EPUBService** | Parse EPUB files, extract text by chapter, build table of contents | Uses EPUBKit (SPM) to unzip/parse OPF/spine, strips HTML to plain text per chapter |
| **WordTokenizer** | Split chapter text into word tokens with metadata | `String` splitting with punctuation-aware logic; produces `[WordToken]` with index, text, sentence boundary flags |
| **RSVPEngine** | Drive word-at-a-time display at configurable WPM | `@Observable` class using `Timer`/`DispatchSourceTimer`; calculates per-word delay from WPM, emits current `WordToken` |
| **PageModeRenderer** | Render full page of text with current-word highlighting | SwiftUI `Text` with `AttributedString`, highlights word at current index from `RSVPEngine` position |
| **TTSService** | Speak text via AVSpeechSynthesizer, report word boundaries | Wraps `AVSpeechSynthesizer` + delegate; translates `willSpeakRangeOfSpeechString` callbacks to word index events |
| **ReadingCoordinator** | Synchronize RSVPEngine position with TTS word boundaries | Arbitrates between timer-driven RSVP and callback-driven TTS; resolves conflicts, handles pause/resume |
| **LibraryManager** | CRUD for books, shelves, reading positions | Thin wrapper over SwiftData queries; handles import, deletion, shelf assignment |
| **GutenbergService** | Fetch curated book lists, download EPUBs | Network layer hitting Project Gutenberg; downloads to app file storage, creates SwiftData Book record |
| **SwiftData Models** | Persistent data schema | `Book`, `Shelf`, `ReadingPosition`, `VoicePreference` models with CloudKit-compatible optionals |
| **CloudKit Sync** | Cross-device sync of library and positions | Automatic via SwiftData `ModelConfiguration(cloudKitDatabase:)` -- no manual CloudKit code needed |

## Recommended Project Structure

```
BlazeBooks/
├── App/
│   ├── BlazeBooksApp.swift          # @main, ModelContainer setup
│   └── ContentView.swift            # Root tab/navigation view
├── Models/
│   ├── Book.swift                   # @Model: title, author, file path, cover
│   ├── Shelf.swift                  # @Model: name, books relationship
│   ├── ReadingPosition.swift        # @Model: book ref, chapter, word index, timestamp
│   └── VoicePreference.swift        # @Model: voice identifier, rate, per-book overrides
├── Services/
│   ├── EPUBService.swift            # EPUB parsing, text extraction
│   ├── WordTokenizer.swift          # Text-to-token splitting
│   ├── RSVPEngine.swift             # Timer-driven word sequencer
│   ├── TTSService.swift             # AVSpeechSynthesizer wrapper
│   ├── ReadingCoordinator.swift     # RSVP + TTS synchronization
│   ├── GutenbergService.swift       # Project Gutenberg API/downloads
│   └── FileStorageService.swift     # EPUB file management on disk
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift        # Main library grid/list
│   │   ├── ShelfView.swift          # Single shelf contents
│   │   ├── BookDetailView.swift     # Book metadata, resume reading
│   │   └── ImportView.swift         # File picker for EPUB import
│   ├── Reading/
│   │   ├── ReadingContainerView.swift  # Hosts RSVP or Page mode
│   │   ├── RSVPView.swift           # Single-word RSVP display
│   │   ├── PageView.swift           # Full-page highlighted text
│   │   ├── ReadingControlsView.swift   # WPM slider, play/pause, chapter nav
│   │   └── TableOfContentsView.swift   # Chapter list navigation
│   ├── Gutenberg/
│   │   ├── GutenbergBrowseView.swift   # Curated lists
│   │   └── GutenbergBookRow.swift      # Single book in list
│   └── Settings/
│       ├── SettingsView.swift       # App-wide settings
│       └── VoicePickerView.swift    # Voice selection + download
└── Utilities/
    ├── Extensions/                  # String, AttributedString helpers
    └── Constants.swift              # WPM range, default values
```

### Structure Rationale

- **Models/:** Isolated SwiftData models. CloudKit sync constrains these (all properties optional or defaulted, no `@Attribute(.unique)`), so they deserve their own group for clarity.
- **Services/:** Business logic separated from views. Each service is an `@Observable` class injected via SwiftUI `.environment()`. Services never import SwiftUI -- they work with plain Swift types.
- **Views/:** Grouped by feature area (Library, Reading, Gutenberg, Settings). Each feature folder contains its own views. No ViewModels -- services + `@Observable` replace the ViewModel layer in modern SwiftUI.
- **Utilities/:** Shared extensions and constants. Kept thin.

## Architectural Patterns

### Pattern 1: @Observable Services as Shared State

**What:** Use `@Observable` classes (iOS 17+) as service objects injected into the SwiftUI environment. Views observe service properties directly -- no separate ViewModel layer needed.

**When to use:** For any shared state that multiple views need (reading position, TTS state, library data). This replaces MVVM's ViewModel with a leaner pattern that fits SwiftUI's reactive model.

**Trade-offs:** Simpler than MVVM (fewer files, less boilerplate). Harder to unit test views in isolation, but services themselves remain fully testable. Apple's recommended direction as of iOS 17.

```swift
@Observable
final class RSVPEngine {
    var currentWord: WordToken?
    var isPlaying: Bool = false
    var wordsPerMinute: Int = 250

    func play() { /* start timer */ }
    func pause() { /* stop timer */ }
}

// In App setup:
let engine = RSVPEngine()
ContentView()
    .environment(engine)

// In View:
struct RSVPView: View {
    @Environment(RSVPEngine.self) var engine
    var body: some View {
        Text(engine.currentWord?.text ?? "")
    }
}
```

### Pattern 2: ReadingCoordinator as Mediator

**What:** A single coordinator object that owns the relationship between RSVPEngine and TTSService. Neither service knows about the other. The coordinator subscribes to both and resolves synchronization.

**When to use:** Whenever two asynchronous systems (timer-driven RSVP, callback-driven TTS) must stay in sync. This is the core architectural challenge of the app.

**Trade-offs:** Adds one more object, but prevents bidirectional coupling between RSVP and TTS. Makes it possible to run RSVP without TTS (silent speed reading) or TTS without RSVP (page mode listening) by simply not activating one side.

```swift
@Observable
final class ReadingCoordinator {
    let rsvpEngine: RSVPEngine
    let ttsService: TTSService
    var mode: ReadingMode  // .rsvpOnly, .ttsOnly, .synchronized

    func startReading(chapter: Chapter, from wordIndex: Int) {
        rsvpEngine.load(chapter.words, startingAt: wordIndex)
        if mode != .rsvpOnly {
            ttsService.speak(chapter.text, from: wordIndex)
        }
        if mode != .ttsOnly {
            rsvpEngine.play()
        }
    }
}
```

### Pattern 3: Word Index as Universal Position

**What:** All components reference reading position as a `(chapterIndex, wordIndex)` tuple. EPUB chapters map to word arrays. TTS character ranges map back to word indices. RSVP timer advances word index. Persistence stores word index.

**When to use:** Always. This is the canonical position representation throughout the app.

**Trade-offs:** Requires the WordTokenizer to produce a stable, deterministic mapping from chapter text to indexed word tokens. Any change to tokenization logic invalidates saved positions -- so the tokenizer must be locked down early and kept stable.

## Data Flow

### Primary Data Flow: EPUB File to Displayed/Spoken Word

```
[EPUB File on Disk]
    │
    ▼
[EPUBService.parse(url:)]
    │  Unzips EPUB, reads OPF manifest + spine order
    │  Parses XHTML content documents
    │  Strips HTML tags, extracts plain text per chapter
    │
    ▼
[Chapter] — struct with: index, title, plainText
    │
    ▼
[WordTokenizer.tokenize(chapter.plainText)]
    │  Splits text on whitespace/punctuation
    │  Produces indexed WordToken array
    │  Marks sentence boundaries (for TTS pause hints)
    │
    ▼
[WordToken] — struct with: index, text, sentenceBoundary flag
    │
    ├──────────────────────────┬──────────────────────────┐
    ▼                          ▼                          ▼
[RSVPEngine]              [PageModeRenderer]         [TTSService]
 Advances wordIndex        Displays full chapter      Speaks chapter text
 by timer at WPM rate      Highlights word at         Fires willSpeakRange
 Emits currentWord         current wordIndex          callbacks per word
    │                          │                          │
    └──────────┬───────────────┘                          │
               ▼                                          │
        [ReadingCoordinator]◄─────────────────────────────┘
         Keeps wordIndex in sync across all three consumers
         In synchronized mode: TTS callbacks drive position,
           RSVP timer is paused/slaved to TTS pace
         In RSVP-only mode: timer drives, TTS inactive
         In page+TTS mode: TTS drives, page highlights follow
               │
               ▼
        [ReadingPosition persisted to SwiftData]
         Saved on pause, chapter change, and periodic autosave
         Syncs to iCloud via CloudKit automatically
```

### TTS-RSVP Synchronization Flow (the hard part)

```
Mode: Synchronized (RSVP display + TTS voice)

1. User taps Play
2. ReadingCoordinator starts TTSService with chapter text
3. TTSService creates AVSpeechUtterance with rate derived from WPM
4. AVSpeechSynthesizer begins speaking
5. willSpeakRangeOfSpeechString fires with character range
6. TTSService converts character range → word index via WordTokenizer mapping
7. ReadingCoordinator receives word index update from TTS
8. ReadingCoordinator sets RSVPEngine.currentWord to match
9. View updates: RSVP shows word, page mode highlights word
10. On pause: both engine and synthesizer pause; position saved

Key insight: In synchronized mode, TTS is the clock source.
The RSVP timer does NOT run independently. TTS word boundary
callbacks drive the display. This prevents drift between
voice and visual display.
```

### WPM-to-TTS Rate Mapping

```
User sets WPM slider (100-500)
    │
    ▼
ReadingCoordinator calculates:
  - RSVP delay = 60.0 / WPM seconds per word
  - TTS rate = map(WPM, from: 100...500, to: 0.3...0.65)
    │
    ▼
If WPM exceeds TTS ceiling (~350-400 WPM depending on voice):
  - Cap TTS rate at AVSpeechUtteranceMaximumSpeechRate
  - Show user a notice: "Voice speed maxed out"
  - In synchronized mode: WPM caps at voice maximum
  - In RSVP-only mode: no cap, timer runs at full speed
```

### Book Import Flow

```
[User selects EPUB via UIDocumentPickerViewController]
    │
    ▼
[FileStorageService.importEPUB(from: url)]
    │  Copies file to app's Documents/Books/ directory
    │  Returns local file URL
    │
    ▼
[EPUBService.parse(url: localURL)]
    │  Extracts metadata: title, author, cover image
    │  Validates structure (has spine, has content docs)
    │
    ▼
[LibraryManager.createBook(metadata:, fileURL:)]
    │  Creates SwiftData Book record
    │  Creates initial ReadingPosition (chapter 0, word 0)
    │
    ▼
[Book appears in LibraryView]
    CloudKit syncs Book record to other devices
    EPUB file itself is NOT synced (too large)
    Other devices show book metadata but prompt re-import
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-50 books | Current architecture is fine. SwiftData handles this trivially. |
| 50-500 books | Library view needs lazy loading. Consider thumbnail caching for covers. |
| 500+ books | Unlikely for most users, but: add search/filter to library, paginate SwiftData queries. |

### Scaling Priorities

1. **First bottleneck:** Large EPUB files (>5MB) may cause slow parsing. Solution: parse on a background Task, show progress indicator, cache parsed chapter text.
2. **Second bottleneck:** TTS with long chapters may consume memory if entire chapter text is held as attributed string. Solution: paginate chapter text into segments, speak segment by segment.

## Anti-Patterns

### Anti-Pattern 1: Bidirectional Coupling Between RSVP and TTS

**What people do:** RSVPEngine directly calls TTSService and vice versa, creating circular dependencies.
**Why it's wrong:** Makes it impossible to run one without the other. Testing requires mocking both. Changes to TTS timing logic ripple into RSVP display code.
**Do this instead:** Use the ReadingCoordinator mediator. RSVPEngine and TTSService are unaware of each other. Coordinator subscribes to events from both and synchronizes them.

### Anti-Pattern 2: Storing Reading Position as Character Offset

**What people do:** Save the character offset into the EPUB text as the reading position.
**Why it's wrong:** Character offsets are fragile. Any change to text extraction logic (whitespace handling, HTML stripping) breaks all saved positions. Character offsets also don't map cleanly between TTS ranges and display words.
**Do this instead:** Use `(chapterIndex, wordIndex)` as the canonical position. Word indices are stable as long as the tokenizer is deterministic. Map TTS character ranges to word indices at runtime.

### Anti-Pattern 3: Parsing EPUB on the Main Thread

**What people do:** Call EPUB parse synchronously when user selects a book.
**Why it's wrong:** EPUB parsing involves unzipping, XML parsing, and HTML stripping -- all CPU-intensive. Blocks UI, causes hangs, triggers watchdog kills.
**Do this instead:** Parse on a background `Task`. Show a loading state. Cache parsed results so subsequent opens are instant.

### Anti-Pattern 4: Using @Attribute(.unique) with CloudKit

**What people do:** Mark Book.title or Book.fileHash as `@Attribute(.unique)` for deduplication.
**Why it's wrong:** CloudKit does not support unique constraints. SwiftData will crash or silently fail on sync.
**Do this instead:** Use manual deduplication logic in the import flow. Check for existing books by file hash before creating a new record.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **Project Gutenberg** | HTTPS fetch of curated JSON/HTML lists, direct EPUB download | No API key needed. Rate limit respectfully. Cache catalog locally. |
| **AVSpeechSynthesizer** | AVFoundation framework, delegate pattern | Runs on-device. Voice packs downloaded on demand. No network needed after download. |
| **CloudKit** | Automatic via SwiftData ModelConfiguration | Requires iCloud entitlement in Xcode. Private database only. Handles conflict resolution automatically. |
| **UIDocumentPicker** | UIKit interop via `UIViewControllerRepresentable` | For importing user EPUB files. Returns security-scoped URL -- must call `startAccessingSecurityScopedResource()`. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **EPUBService -> WordTokenizer** | Direct call: `tokenize(text) -> [WordToken]` | Synchronous, pure function. No state. |
| **RSVPEngine <-> ReadingCoordinator** | Coordinator observes engine's `@Observable` properties | One-way observation. Coordinator can set engine properties. |
| **TTSService -> ReadingCoordinator** | Async callback via closure/delegate: `onWordBoundary: (Int) -> Void` | TTS fires callbacks on arbitrary thread; coordinator dispatches to main. |
| **LibraryManager <-> SwiftData** | ModelContext queries and inserts | Always on `@MainActor`. Use `modelContext.fetch()` with predicates. |
| **Views <-> Services** | SwiftUI `.environment()` injection | Views read `@Observable` service properties. Call service methods for actions. |

## Build Order (Dependency Chain)

Components should be built in this order based on dependencies:

```
Phase 1: Foundation (no dependencies)
├── SwiftData Models (Book, Shelf, ReadingPosition, VoicePreference)
├── WordTokenizer (pure function, no dependencies)
└── EPUBService (depends only on EPUBKit SPM package)

Phase 2: Core Reading (depends on Phase 1)
├── RSVPEngine (depends on WordTokenizer output types)
├── TTSService (depends on AVFoundation, WordTokenizer for index mapping)
└── FileStorageService (file management, no model dependencies)

Phase 3: Coordination (depends on Phase 2)
├── ReadingCoordinator (depends on RSVPEngine + TTSService)
└── LibraryManager (depends on SwiftData Models + EPUBService)

Phase 4: UI (depends on Phase 3)
├── Reading views (RSVPView, PageView, controls) -- depend on ReadingCoordinator
├── Library views -- depend on LibraryManager
└── Settings views -- depend on TTSService for voice picker

Phase 5: Network + Sync (can parallel with Phase 4)
├── GutenbergService (network layer, depends on FileStorageService + LibraryManager)
└── CloudKit configuration (SwiftData ModelConfiguration, entitlements)
```

**Why this order:**
- Models and tokenizer are leaf dependencies with no upstream requirements. Build and test them first.
- RSVP and TTS can be developed and tested independently before being wired together through the coordinator.
- The coordinator is the architectural keystone -- it can only be built once both engines exist.
- UI is last because it consumes services. Building services first means views are trivial to implement.
- CloudKit sync and Gutenberg are additive features that don't affect core reading flow.

## Sources

- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata) -- HIGH confidence (Context7 verified)
- [SwiftData CloudKit Sync Rules](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) -- MEDIUM confidence (verified against Apple docs)
- [AVSpeechSynthesizer Documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) -- HIGH confidence (Apple official)
- [willSpeakRangeOfSpeechString delegate method](https://www.hackingwithswift.com/example-code/media/how-to-highlight-text-to-speech-words-being-read-using-avspeechsynthesizer) -- HIGH confidence (verified code example)
- [EPUBKit Swift Parser](https://github.com/witekbobrowski/EPUBKit) -- MEDIUM confidence (actively maintained, Swift 6+, updated Nov 2025)
- [EPUB 3 File Structure](https://www.edrlab.org/open-standards/anatomy-of-an-epub-3-file/) -- HIGH confidence (standards body)
- [RSVP and Optimal Recognition Point](https://easyreads.ai/blog/rapid-serial-visual-presentation) -- MEDIUM confidence (educational source, consistent with research literature)
- [SwiftUI @Observable Architecture Patterns](https://nalexn.github.io/clean-architecture-swiftui/) -- MEDIUM confidence (multiple sources agree)

---
*Architecture research for: Blaze Books -- iOS RSVP ebook reader with synchronized TTS*
*Researched: 2026-02-20*
