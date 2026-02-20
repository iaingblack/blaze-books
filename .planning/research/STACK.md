# Stack Research

**Domain:** iOS RSVP ebook reader with synchronized text-to-speech
**Researched:** 2026-02-20
**Confidence:** MEDIUM-HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.x | Language | Required for modern concurrency (async/await), strict concurrency checking. Xcode 16+ ships with Swift 6. |
| SwiftUI | iOS 17+ | UI framework | Declarative, first-class Apple support, required for SwiftData integration. TextRenderer (backported to iOS 17) enables custom text drawing for RSVP. Project constraint already mandates this. |
| SwiftData | iOS 17+ | Persistence + CloudKit sync | Built-in iCloud sync with minimal boilerplate. Apple's modern persistence layer. Project constraint already mandates this. |
| AVFoundation | iOS 17+ | Text-to-speech | AVSpeechSynthesizer provides word-by-word delegate callbacks (`willSpeakRangeOfSpeechString`), SSML support (iOS 16+), Personal Voice (iOS 17+), on-device voice download. No third-party alternative exists for on-device iOS TTS. |

**Confidence: HIGH** -- All are first-party Apple frameworks mandated by project constraints and verified via Apple developer documentation and Context7.

### EPUB Parsing

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Readium Swift Toolkit | 3.6.0 | EPUB parsing, text extraction, chapter navigation | Industry-standard open-source toolkit (EDRLab/Readium Foundation). Provides `Publication.content().elements()` for full text extraction, `tableOfContents` for chapter structure, built-in `PublicationSpeechSynthesizer` with word-level tokenization, and `DecorableNavigator` for utterance highlighting. SPM support. Active development (3.6.0 released Jan 2026). |

**Confidence: HIGH** -- Verified via Context7 (`/readium/swift-toolkit`, benchmark 86.7, High reputation). Documentation confirms text extraction API, TTS integration with word-by-word tokenization, and page-turn synchronization.

#### Why Readium over alternatives

Readium is the correct choice for this project because it provides **both** EPUB parsing and a built-in TTS orchestration layer (`PublicationSpeechSynthesizer`) that handles content tokenization, utterance sequencing, and word-level locator tracking. This directly solves the core "synchronized reading and listening" requirement without building that orchestration from scratch.

Key Readium capabilities verified via Context7:

1. **Text extraction**: `publication.content().elements()` with `TextualContentElement` for clean text.
2. **Chapter navigation**: `publication.tableOfContents` returns structured `Link` objects with titles and hrefs.
3. **TTS orchestration**: `PublicationSpeechSynthesizer` iterates publication content, splits into utterances via `ContentTokenizer`, feeds to `TTSEngine`.
4. **Word-level tokenization**: Custom `tokenizerFactory` with `makeDefaultTextTokenizer(unit: .word)` for word-by-word utterances.
5. **Utterance highlighting**: `PublicationSpeechSynthesizerDelegate` provides `.playing(utterance, range:)` state with locator for `Decoration` overlays.
6. **Auto page-turn**: `navigator.go(to: range)` synchronizes the visible page with spoken content.
7. **Voice utilities** (v3.5.0+): `[TTSVoice].filterByLanguage(_:)` and `[TTSVoice].sorted()` for voice selection UI.

### Project Gutenberg Integration

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Gutendex API | N/A (hosted) | Book metadata + EPUB download URLs | Free, no auth required, JSON REST API at `gutendex.com/books`. Returns book metadata with direct EPUB download links from Project Gutenberg mirrors. Supports search, language filtering, topic filtering, sorting by popularity. |
| URLSession | iOS 17+ | HTTP networking | First-party, async/await support, no reason for a third-party HTTP client for this use case. |

**Confidence: HIGH** -- Gutendex is the de facto standard API for Project Gutenberg. Verified endpoint structure: `GET /books?search=dickens&mime_type=application/epub` returns paginated JSON with `formats` dict containing EPUB URLs. No auth key needed.

#### Gutendex API details

- **Base URL**: `https://gutendex.com/books`
- **Key parameters**: `search`, `languages` (e.g., `en`), `topic`, `mime_type`, `sort` (popular/ascending/descending), `ids`
- **Response**: `{ count, next, previous, results: [Book] }` where each Book has `id`, `title`, `authors`, `subjects`, `formats` (dict of MIME type to URL), `download_count`
- **EPUB access**: `book.formats["application/epub+zip"]` gives the direct download URL
- **Rate limiting**: None documented, but be respectful; cache aggressively since catalog changes infrequently
- **Offline strategy**: Download EPUB files to local storage, cache metadata in SwiftData

### Data Layer

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftData | iOS 17+ | Local persistence + iCloud sync | `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.BlazeBooks"))` enables sync with one line. Handles library, reading positions, shelves, and book metadata. |

**Confidence: MEDIUM** -- SwiftData + CloudKit works but has real constraints (see below). Verified via Apple docs (Context7) and multiple community sources.

#### SwiftData + CloudKit constraints (verified)

These are non-negotiable rules when using CloudKit sync:

1. **All properties must be optional or have default values.** CloudKit cannot enforce non-nil at the schema level.
2. **All relationships must be optional.** Required relationships will cause sync failures.
3. **No `@Attribute(.unique)`.** CloudKit does not support uniqueness constraints. Sync will silently fail.
4. **Private database only.** SwiftData CloudKit sync only works with the user's private database. No public or shared database support.
5. **Add-only schema migration.** Once deployed, you cannot rename or delete model properties. You can only add new ones. A rename is treated as delete + add, causing data loss.
6. **Not real-time sync.** Apple controls sync frequency based on device conditions. Expect seconds-to-minutes latency, not instant.
7. **Use `@Query` for observation.** Dynamic `@Query` properly notifies SwiftUI of remote changes. Direct property access may miss CloudKit updates.
8. **Debug schema initialization.** Use `NSPersistentCloudKitContainer.initializeCloudKitSchema()` in debug builds to push schema to CloudKit dashboard, then deploy to production before shipping.

**Sources:** Apple Developer Documentation (Context7), fatbobman.com, hackingwithswift.com, carolanelefebvre.medium.com

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ReadiumShared | 3.6.0 (part of Readium) | Core publication models, content API | Always -- provides Publication, Locator, Content types |
| ReadiumStreamer | 3.6.0 (part of Readium) | EPUB parsing and opening | Always -- provides PublicationOpener, AssetRetriever |
| ReadiumNavigator | 3.6.0 (part of Readium) | Page rendering, decoration overlays | Page reading mode -- provides DecorableNavigator for word highlighting |
| SwiftSoup | 2.7.x | HTML parsing | If Readium's text extraction needs supplementation for edge-case EPUBs with complex HTML. Likely not needed for v1. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | IDE, build system | Required for Swift 6, iOS 17+ SDK, SwiftData |
| Xcode Previews | SwiftUI iteration | Essential for rapid RSVP display tuning |
| CloudKit Dashboard | iCloud schema management | Deploy dev schema to production before TestFlight |
| Instruments (Time Profiler) | Performance profiling | Critical for RSVP timing accuracy at high WPM |
| Instruments (SwiftUI view body) | View invalidation debugging | Ensure RSVP word changes don't trigger excessive redraws |

## RSVP Implementation Strategy

This is the novel technical challenge. No SwiftUI RSVP libraries exist; this must be built from scratch.

### Architecture: Timer-driven state machine

```
Timer fires at WPM interval
  -> Update @State currentWord
    -> SwiftUI Text view re-renders single word
      -> (Optional) AVSpeechSynthesizer speaks in parallel
```

### Key implementation details

| Concern | Approach | Rationale |
|---------|----------|-----------|
| **Timer mechanism** | `Timer.publish(every:on:in:)` with `.main` RunLoop | Standard SwiftUI pattern. At 500 WPM = 120ms intervals, this is well within SwiftUI's rendering budget. `CADisplayLink` is overkill. |
| **Word display** | Single `Text(currentWord)` with `.font(.system(size: 48+))`, `.monospacedDigit()`, `.contentTransition(.opacity)` | Large centered text, opacity transition prevents jarring jumps. Monospaced prevents width jitter. |
| **ORP (Optimal Recognition Point)** | Color the pivot letter (typically 1/3 into word) differently using `AttributedString` | Standard RSVP technique. Helps eyes lock on the recognition point. |
| **Pause on punctuation** | Add 1.5-2x delay after sentences (`.`, `!`, `?`) and 1.2x after commas | Improves comprehension at speed. Well-established RSVP practice. |
| **WPM to timer interval** | `interval = 60.0 / Double(wpm)` seconds | Direct conversion. 300 WPM = 200ms per word. |
| **View isolation** | Extract RSVP word display into a minimal subview | Prevents WPM slider changes or other state from causing unnecessary redraws of the word display. |

**Confidence: MEDIUM** -- RSVP implementation pattern is well-understood conceptually. SwiftUI Timer at 120ms intervals is within normal rendering bounds per Swift Forums discussions, but real-device testing is required to confirm smooth performance at 500 WPM.

## AVSpeechSynthesizer Integration Strategy

### Rate mapping: WPM to AVSpeechUtterance.rate

| Constant | Value | Approximate WPM |
|----------|-------|-----------------|
| `AVSpeechUtteranceMinimumSpeechRate` | 0.0 | ~60 WPM |
| `AVSpeechUtteranceDefaultSpeechRate` | 0.5 | ~180 WPM |
| `AVSpeechUtteranceMaximumSpeechRate` | 1.0 | ~300-350 WPM |

The rate is a `Float` from 0.0 to 1.0. The relationship to actual WPM is nonlinear and voice-dependent. There is **no Apple API to query exact WPM for a given rate**. This means:

1. **Empirical calibration required.** Map WPM slider values to rate floats through testing with target voices.
2. **Voice speed caps at synthesizer maximum.** Per PROJECT.md, when user WPM exceeds what the voice can deliver (~300-350 WPM), the voice should cap gracefully and display a warning rather than produce garbled audio.
3. **RSVP continues independently.** RSVP display speed and voice speed are separate control loops. When voice caps out, RSVP can continue faster while voice plays at maximum rate.

### Word-by-word synchronization

The `AVSpeechSynthesizerDelegate` method `willSpeakRangeOfSpeechString:utterance:` fires before each word is spoken, providing an `NSRange` into the utterance text. This is the hook for:

- **Page mode**: Highlight the current word in the full-page view.
- **RSVP mode**: Verify RSVP display is tracking voice position (or re-sync if drifted).

### SSML support (iOS 16+)

`AVSpeechUtterance(ssmlRepresentation:)` allows fine-grained control:
- `<break time="300ms"/>` for paragraph pauses
- `<prosody rate="slow">` for emphasis sections
- `<say-as>` for numbers, dates, abbreviations

Useful for v2 enhancements but not required for v1.

### Voice management

- `AVSpeechSynthesisVoice.speechVoices()` lists all available voices.
- Enhanced/premium voices require download: check `voice.quality` property.
- Personal Voice (iOS 17+) available via `AVSpeechSynthesisVoice(identifier:)` if user has created one.
- Readium's `[TTSVoice].filterByLanguage(_:)` and `.sorted()` utilities simplify voice picker UI.

**Confidence: HIGH** -- AVSpeechSynthesizer delegate callbacks are well-documented (Apple docs, Hacking with Swift, Context7). SSML support verified. The WPM-to-rate mapping uncertainty is a known challenge requiring empirical testing.

## Installation

```swift
// Package.swift dependencies
dependencies: [
    .package(
        url: "https://github.com/readium/swift-toolkit.git",
        from: "3.6.0"
    ),
],
targets: [
    .target(
        name: "BlazeBooks",
        dependencies: [
            .product(name: "ReadiumShared", package: "swift-toolkit"),
            .product(name: "ReadiumStreamer", package: "swift-toolkit"),
            .product(name: "ReadiumNavigator", package: "swift-toolkit"),
            .product(name: "ReadiumOPDS", package: "swift-toolkit"),  // Only if OPDS catalog browsing needed
        ]
    ),
]
```

No CocoaPods, no Carthage. SPM only. Readium is the sole third-party dependency for v1.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Readium Swift Toolkit | EPUBKit | If you only need metadata extraction (title, author, TOC) without text content or rendering. EPUBKit is simpler but lacks text extraction, TTS orchestration, and navigator. The author notes it is "not recommended for larger projects." |
| Readium Swift Toolkit | FolioReaderKit | Never for new projects. Last meaningful update was years ago. UIKit-based, not SwiftUI. Has TTS and media overlay support but is effectively unmaintained. |
| Readium Swift Toolkit | Custom XML/HTML parsing (SwiftSoup + Zip) | If Readium proves too heavy and you only need text extraction. You could unzip EPUB, parse `content.opf` for spine order, parse HTML chapters with SwiftSoup. Significantly more work, no TTS orchestration, but zero dependency weight. |
| SwiftData + CloudKit | SQLiteData (Point-Free) | If SwiftData's CloudKit limitations prove too painful. SQLiteData 1.0 (2025) is built on GRDB + CloudKit, supports sharing (not just private sync), and has fewer schema constraints. However, it adds a significant dependency, has a newer/smaller community, and the project constraints already specify SwiftData. Consider as escape hatch if SwiftData sync reliability is unacceptable. |
| SwiftData + CloudKit | Core Data + CloudKit | If you hit a SwiftData bug that blocks shipping. SwiftData wraps Core Data internally, so you can drop down when needed. Same CloudKit constraints apply. |
| AVSpeechSynthesizer | Third-party TTS (Azure, Google, ElevenLabs) | Never for v1. Requires network, adds cost, adds latency. AVSpeechSynthesizer works offline, is free, and integrates natively with iOS voice management. Consider only if voice quality becomes a user complaint in v2+. |
| URLSession | Alamofire | Never for this project. The Gutendex API is simple REST. URLSession with async/await handles it cleanly. No need for a networking abstraction layer. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| FolioReaderKit | Unmaintained, UIKit-only, no SwiftUI integration, stale dependencies | Readium Swift Toolkit |
| Alamofire / Moya | Over-engineered for simple REST calls to Gutendex. Adds dependency surface for no benefit. | URLSession with async/await |
| Realm / Firebase | Project specifies SwiftData + CloudKit. These would fight the constraint. | SwiftData |
| WKWebView for RSVP | Massive overhead for displaying a single word. WebView is for rich EPUB rendering (page mode via Readium Navigator), not RSVP. | Native SwiftUI Text view |
| Combine for Timer | While functional, `Timer.publish` with `.onReceive` is the idiomatic SwiftUI approach. Avoid raw Combine pipelines for RSVP timing; keep it simple. | `Timer.publish(every:on:in:).autoconnect()` with `.onReceive` |
| `async let` / TaskGroup for TTS orchestration | Readium's `PublicationSpeechSynthesizer` already handles utterance sequencing. Don't re-implement concurrency for TTS. | Readium's built-in TTS orchestration |

## Stack Patterns by Variant

**If user imports their own EPUB (primary flow):**
- Use Readium's `AssetRetriever` + `PublicationOpener` to parse the local file
- Store book metadata in SwiftData for library view
- Store file reference (bookmark URL) for re-opening
- Extract text via `publication.content().elements()`

**If user downloads from Project Gutenberg:**
- Fetch metadata from Gutendex API via URLSession
- Download EPUB from `book.formats["application/epub+zip"]` URL
- Save to app's Documents directory
- Then treat identically to imported EPUB

**If RSVP mode (single word display):**
- Pre-extract all words from current chapter using Readium content API
- Drive display with Timer at WPM-derived interval
- Optionally run AVSpeechSynthesizer in parallel (capped at max rate)
- Track position as word index within chapter

**If Page mode (full page with highlighting):**
- Use Readium's `EPUBNavigatorViewController` (wrapped in `UIViewControllerRepresentable` for SwiftUI)
- Use `PublicationSpeechSynthesizer` for TTS with `DecorableNavigator` for word highlighting
- Use delegate callbacks to auto-turn pages

## Version Compatibility

| Component | Minimum iOS | Notes |
|-----------|-------------|-------|
| SwiftUI (required features) | iOS 17.0 | TextRenderer backported to 17. Content transitions available from 16. |
| SwiftData | iOS 17.0 | First release. Significant improvements in iOS 18 but 17 is functional. |
| SwiftData + CloudKit | iOS 17.0 | `ModelConfiguration(cloudKitDatabase:)` available from 17.0. |
| AVSpeechSynthesizer | iOS 7.0+ | Core API ancient. Personal Voice requires iOS 17+. SSML requires iOS 16+. |
| Readium Swift Toolkit 3.6.0 | iOS 16.0 | Readium 3.x requires iOS 16+. Compatible with our iOS 17+ target. |
| Gutendex API | N/A | Web API, no iOS version dependency. |

**Project minimum: iOS 17.0** -- All components are compatible.

## Sources

- `/readium/swift-toolkit` (Context7, benchmark 86.7, High reputation) -- EPUB parsing, text extraction, TTS orchestration, word-level tokenization, decoration/highlighting APIs
- `/websites/developer_apple_swiftdata` (Context7, benchmark 76.3, High reputation) -- SwiftData CloudKit configuration, ModelConfiguration, schema initialization
- `/websites/developer_apple_swiftui` (Context7, benchmark 87.3, High reputation) -- ContentTransition, text animation, interpolation
- [Apple AVSpeechSynthesizer documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) -- Rate constants, delegate callbacks, voice management
- [Hacking with Swift: AVSpeechSynthesizer word highlighting](https://www.hackingwithswift.com/example-code/media/how-to-highlight-text-to-speech-words-being-read-using-avspeechsynthesizer) -- willSpeakRangeOfSpeechString delegate pattern
- [Hacking with Swift: SwiftData + CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit) -- Sync setup and constraints
- [fatbobman.com: Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) -- Schema migration constraints, CloudKit rules
- [fatbobman.com: Designing Models for CloudKit Sync](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) -- Add-only schema migration, optional properties rule
- [Gutendex API](https://gutendex.com/) -- REST API documentation, endpoint parameters
- [Gutendex GitHub](https://github.com/garethbjohnson/gutendex) -- API source and documentation
- [Readium Swift Toolkit TTS Guide](https://github.com/readium/swift-toolkit/blob/develop/docs/Guides/TTS.md) -- PublicationSpeechSynthesizer, word tokenization, decoration highlighting
- [Readium Swift Toolkit 3.5.0 Release](https://blog.readium.org/release-note-swift-toolkit-version-3-5-0/) -- TTS voice utilities, layout improvements
- [Point-Free SQLiteData](https://github.com/pointfreeco/sqlite-data) -- SwiftData alternative assessment
- [Swift Forums: SwiftUI high-frequency updates](https://forums.swift.org/t/how-to-update-swiftui-many-times-a-second-while-being-performant/71249) -- Timer-driven SwiftUI performance
- [fatbobman.com: TextRenderer effects](https://fatbobman.com/en/posts/creating-stunning-dynamic-text-effects-with-textrender/) -- TextRenderer protocol for custom text drawing

---
*Stack research for: iOS RSVP ebook reader with synchronized TTS*
*Researched: 2026-02-20*
