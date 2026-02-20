# Phase 1: Foundation - Research

**Researched:** 2026-02-20
**Domain:** EPUB parsing, SwiftData models, file import, word tokenization (iOS 17+)
**Confidence:** HIGH

## Summary

Phase 1 establishes the data foundation for Blaze Books: importing EPUB files, parsing them into clean chapter-structured text, tokenizing words for position tracking, and persisting everything in CloudKit-compatible SwiftData models. The primary technical risk is EPUB parsing robustness against real-world malformed files, which Readium Swift Toolkit handles well due to its internal use of SwiftSoup (HTML) and Fuzi (XML) lenient parsers.

The recommended approach is: use SwiftUI's `.fileImporter` modifier for EPUB import, Readium Swift Toolkit 3.7.0 for EPUB parsing and text extraction, Apple's NLTokenizer from the NaturalLanguage framework for word/sentence tokenization, and SwiftData with VersionedSchema from day one for CloudKit-compatible persistence.

**Primary recommendation:** Use Readium's `Publication.content().elements()` API for text extraction and `publication.tableOfContents` for chapter structure. Do NOT hand-roll EPUB parsing -- the format's real-world malformation rate makes it a multi-month rabbit hole.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| EPUB-01 | User can import DRM-free EPUB files via iOS Files app | SwiftUI `.fileImporter` with `UTType.epub`, security-scoped URL handling, copy to app sandbox |
| EPUB-02 | App extracts clean text with chapter structure from EPUB files | Readium `Publication.content().elements()` for text, `publication.tableOfContents` for chapters |
| EPUB-03 | App handles malformed EPUB XML gracefully without crashing | Readium uses SwiftSoup + Fuzi internally for lenient HTML/XML parsing; wrap `publicationOpener.open()` in error handling |
| EPUB-04 | Imported books work fully offline without internet connection | Copy EPUB to app's Documents directory on import; Readium opens from local file URL; SwiftData persists metadata locally |
| LIB-05 | App auto-saves reading position per book | SwiftData `ReadingPosition` model with `chapterIndex` + `wordIndex`; save on pause, chapter change, app background |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Readium Swift Toolkit | 3.7.0 | EPUB parsing, text extraction, chapter navigation | Industry-standard open-source toolkit (EDRLab/Readium Foundation). Handles EPUB 2/3, malformed XML, entity resolution. Uses SwiftSoup + Fuzi internally. 268 code snippets in Context7, benchmark 86.7, High reputation. SPM support. |
| SwiftData | iOS 17+ | Persistence with CloudKit sync | Apple's modern persistence layer. `ModelConfiguration(cloudKitDatabase: .private(...))` enables iCloud sync. Required by project constraints. |
| NaturalLanguage (NLTokenizer) | iOS 17+ | Word and sentence tokenization | Apple's first-party NLP framework. Language-aware tokenization handles edge cases (contractions, hyphenated words, CJK) that manual string splitting misses. |
| SwiftUI | iOS 17+ | UI framework, file import | `.fileImporter` modifier provides native file picker. No need for `UIDocumentPickerViewController` wrapping. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ReadiumShared | 3.7.0 (part of Readium) | Core Publication models, Locator, Content types | Always -- provides Publication, Link, Locator, ContentElement types |
| ReadiumStreamer | 3.7.0 (part of Readium) | EPUB parsing and opening | Always -- provides AssetRetriever, PublicationOpener, DefaultPublicationParser |
| UniformTypeIdentifiers | iOS 17+ | `UTType.epub` for file picker filtering | Always -- used with `.fileImporter(allowedContentTypes:)` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Readium Swift Toolkit | EPUBKit | Simpler but metadata-only -- no text content extraction, no TTS orchestration. Author notes "not recommended for larger projects." |
| Readium Swift Toolkit | Custom XML/HTML (SwiftSoup + Zip) | Full control but 2-4 months of work to handle real-world EPUB malformations. No TTS orchestration. Readium already uses SwiftSoup internally. |
| NLTokenizer | Manual String splitting | Simpler but breaks on contractions, hyphenated words, Unicode. NLTokenizer handles 40+ languages correctly. |
| SwiftUI `.fileImporter` | UIDocumentPickerViewController wrapped in UIViewControllerRepresentable | More control but unnecessary complexity. `.fileImporter` handles security-scoped URLs natively since iOS 14. |

### Installation

```swift
// In Xcode: File > Add Package Dependencies
// URL: https://github.com/readium/swift-toolkit.git
// Version: from 3.7.0

// Or in Package.swift:
dependencies: [
    .package(
        url: "https://github.com/readium/swift-toolkit.git",
        from: "3.7.0"
    ),
],
targets: [
    .target(
        name: "BlazeBooks",
        dependencies: [
            .product(name: "ReadiumShared", package: "swift-toolkit"),
            .product(name: "ReadiumStreamer", package: "swift-toolkit"),
        ]
    ),
]
```

**Note:** ReadiumNavigator is NOT needed for Phase 1. Only add it in Phase 3 (page mode rendering). Phase 1 only needs ReadiumShared + ReadiumStreamer for parsing and text extraction.

## Architecture Patterns

### Recommended Project Structure (Phase 1 scope)

```
BlazeBooks/
├── App/
│   ├── BlazeBooksApp.swift          # @main, ModelContainer setup with VersionedSchema
│   └── ContentView.swift            # Root navigation (placeholder for Phase 1)
├── Models/
│   ├── SchemaV1.swift               # VersionedSchema with all v1 models
│   ├── Book.swift                   # @Model: title, author, filePath, coverData
│   ├── Chapter.swift                # @Model: title, index, wordCount, book relationship
│   └── ReadingPosition.swift        # @Model: chapterIndex, wordIndex, timestamp, book relationship
├── Services/
│   ├── EPUBImportService.swift      # File import + copy to sandbox
│   ├── EPUBParserService.swift      # Readium parsing, text extraction, chapter building
│   ├── WordTokenizer.swift          # NLTokenizer wrapper for word/sentence tokenization
│   └── ReadingPositionService.swift # Position tracking, auto-save logic
├── Views/
│   └── Import/
│       └── ImportButton.swift       # .fileImporter trigger + import progress
└── Utilities/
    └── FileStorageManager.swift     # App Documents/Books/ directory management
```

### Pattern 1: @Observable Service with SwiftUI Environment Injection

**What:** Create `@Observable` service classes injected via SwiftUI `.environment()`. Views observe service properties directly. No ViewModel layer.

**When to use:** For all shared state in Phase 1 (import progress, parsing state, position tracking).

```swift
// Source: Apple Developer Documentation (iOS 17 @Observable pattern)
import Observation

@Observable
final class EPUBParserService {
    var isParsing: Bool = false
    var parseProgress: Double = 0.0
    var lastError: String?

    func parse(epubURL: URL) async throws -> ParsedBook {
        isParsing = true
        defer { isParsing = false }
        // Readium parsing here
    }
}

// In App setup:
@main
struct BlazeBooksApp: App {
    let parserService = EPUBParserService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(parserService)
        }
        .modelContainer(for: Book.self)
    }
}

// In View:
struct ImportButton: View {
    @Environment(EPUBParserService.self) var parser

    var body: some View {
        if parser.isParsing {
            ProgressView(value: parser.parseProgress)
        }
    }
}
```

### Pattern 2: Security-Scoped URL File Import

**What:** Use SwiftUI `.fileImporter` to get a security-scoped URL, then copy the EPUB to the app's sandbox before releasing the security scope.

**When to use:** Every EPUB import. The security scope is temporary -- you must copy the file before it expires.

```swift
// Source: Apple Developer Documentation, useyourloaf.com
struct ImportButton: View {
    @State private var showingImporter = false
    @Environment(EPUBImportService.self) var importService

    var body: some View {
        Button("Import EPUB") { showingImporter = true }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.epub],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        await importService.importEPUB(from: url)
                    }
                case .failure(let error):
                    // Handle picker error
                    print("Import failed: \(error)")
                }
            }
    }
}
```

### Pattern 3: VersionedSchema from Day One

**What:** Define all SwiftData models inside a `VersionedSchema` enum from the first version. This is mandatory for CloudKit compatibility and safe future migrations.

**When to use:** Always. There is no safe way to retrofit VersionedSchema after shipping.

```swift
// Source: Apple Developer Documentation, azamsharp.com
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Book.self,
        Chapter.self,
        ReadingPosition.self,
    ]

    @Model
    final class Book {
        var id: UUID = UUID()
        var title: String = ""
        var author: String = ""
        var filePath: String = ""       // Relative path within Documents/Books/
        var coverImageData: Data?       // Optional: extracted cover
        var importDate: Date = Date()
        var chapterCount: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
        var chapters: [Chapter]? = []

        @Relationship(deleteRule: .cascade, inverse: \ReadingPosition.book)
        var readingPosition: ReadingPosition?

        init() {}
    }

    @Model
    final class Chapter {
        var id: UUID = UUID()
        var title: String = ""
        var index: Int = 0
        var wordCount: Int = 0
        var book: Book?

        init() {}
    }

    @Model
    final class ReadingPosition {
        var id: UUID = UUID()
        var chapterIndex: Int = 0
        var wordIndex: Int = 0
        var lastReadDate: Date = Date()
        var book: Book?

        init() {}
    }
}

enum BlazeBooksMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []
}
```

### Pattern 4: Word Index as Universal Position

**What:** Store reading position as `(chapterIndex: Int, wordIndex: Int)`. All components (RSVP, page mode, TTS, persistence) use this as the canonical position format.

**When to use:** Always. This must be established in Phase 1 and locked down because all future phases depend on it.

**Why not character offset:** Character offsets break when text extraction logic changes (whitespace normalization, entity resolution). Word indices are stable as long as the tokenizer is deterministic.

### Anti-Patterns to Avoid

- **Parsing EPUB on the main thread:** EPUB parsing involves unzipping, XML parsing, and HTML stripping. Always parse on a background `Task`. Show loading state.
- **Storing the full EPUB text in SwiftData:** EPUB text can be megabytes. Store only metadata in SwiftData. Re-extract text from the EPUB file on demand (cache in memory).
- **Using `@Attribute(.unique)` with CloudKit:** CloudKit does not support unique constraints. Sync will silently fail. Use manual deduplication (check by file hash before creating records).
- **Not copying EPUB to app sandbox:** Security-scoped URLs are temporary. If you keep a reference to the original URL, the file becomes inaccessible after the security scope expires.
- **Skipping VersionedSchema for v1:** Once you ship without VersionedSchema, adding it later requires a destructive migration or complex workaround. Trivial to add upfront, painful to retrofit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| EPUB parsing (unzip, OPF, spine, manifest) | Custom ZIP + XML parser | Readium Swift Toolkit | 10-20% of real EPUBs are malformed. Readium handles entity resolution, encoding issues, missing manifests. Months of edge-case work avoided. |
| HTML to plain text extraction | Regex stripping or custom SAX parser | Readium's `Content` API (`TextualContentElement`) | Readium uses SwiftSoup internally. Handles nested tags, entities, encoding. Your regex will break on the first Gutenberg book. |
| Word tokenization | `String.split(separator: " ")` | NLTokenizer(unit: .word) | Manual splitting breaks on: contractions ("don't" = 1 word not 2), hyphenated words, em-dashes without spaces, ellipsis, CJK text. NLTokenizer handles all of these correctly across 40+ languages. |
| Sentence boundary detection | Splitting on ". " | NLTokenizer(unit: .sentence) | Abbreviations ("Dr. Smith"), decimal numbers ("3.14"), ellipsis ("...") all produce false sentence boundaries with naive splitting. |
| File import security-scoped URL handling | Custom UIDocumentPickerViewController wrapper | SwiftUI `.fileImporter` modifier | `.fileImporter` handles presentation, security scope, and result delivery. Available since iOS 14. No UIKit bridging needed. |
| CloudKit sync | Manual CKRecord management | SwiftData `ModelConfiguration(cloudKitDatabase:)` | One line of configuration vs hundreds of lines of CKRecord mapping. SwiftData handles conflict resolution, schema management, and change tracking. |

**Key insight:** Phase 1 has zero novel problems. Every component has a mature, well-tested solution. The value is in wiring them together correctly, not in building custom implementations.

## Common Pitfalls

### Pitfall 1: CloudKit Schema Lock-in

**What goes wrong:** Once deployed to production CloudKit, you cannot delete entities, remove attributes, or change attribute types. Only adding new fields is permitted. Ship the wrong model and you carry that schema debt forever.

**Why it happens:** CloudKit's production schema ensures backward compatibility across app versions. Developers accustomed to local database migrations don't internalize this restriction until after their first App Store release.

**How to avoid:**
- Use VersionedSchema from day one (Pattern 3 above)
- All properties must have default values or be optional
- All relationships must be optional
- No `@Attribute(.unique)` -- CloudKit does not support it
- Do NOT deploy to production CloudKit until the model is validated through testing
- Test exhaustively in the development CloudKit environment first

**Warning signs:** Non-optional properties in your models, `@Attribute(.unique)` on any field, no VersionedSchema in place.

### Pitfall 2: EPUB Parsing Fails on Real-World Files

**What goes wrong:** EPUB files from Project Gutenberg contain malformed XML, undeclared HTML entities (`&nbsp;`, `&mdash;`), missing file references, XML 1.1 declarations, and inconsistent encoding. A parser that works on test files fails on 10-20% of real EPUBs.

**Why it happens:** The EPUB spec requires XHTML (which only defines 5 entities), but tools that generate EPUBs use HTML entities freely. Project Gutenberg EPUBs specifically have known encoding and entity quirks.

**How to avoid:**
- Use Readium (which handles this internally via SwiftSoup + Fuzi lenient parsers)
- Wrap `publicationOpener.open()` in error handling -- catch failures and show user-friendly error
- Test with 20+ diverse Project Gutenberg EPUBs before considering parsing "done"
- Build a fallback: if Readium fails to extract text for a chapter, show "Chapter content unavailable" rather than crashing

**Warning signs:** Parser crashes or returns empty content for specific books, special characters render as `?`, chapter detection misses chapters.

### Pitfall 3: Security-Scoped URL Expiration

**What goes wrong:** After the user picks an EPUB via `.fileImporter`, the returned URL has a temporary security scope. If you store the URL and try to use it later (e.g., on next app launch), access is denied with no useful error.

**Why it happens:** iOS grants temporary access to files outside the app sandbox. The scope expires when you call `stopAccessingSecurityScopedResource()` or when the app terminates.

**How to avoid:**
- Immediately copy the EPUB file to your app's `Documents/Books/` directory within the security scope
- Store the relative path (within your sandbox) in SwiftData, not the original URL
- Call `startAccessingSecurityScopedResource()` before access, `stopAccessingSecurityScopedResource()` in a defer block after copy

**Warning signs:** Books work after import but fail to open after app restart. "The file couldn't be opened because you don't have permission."

### Pitfall 4: Large EPUB Memory Pressure

**What goes wrong:** Loading an entire EPUB into memory at once (all chapters, all text) triggers iOS memory pressure termination. No crash log -- the app just disappears. EPUBs with embedded images can be 50-100MB+.

**Why it happens:** Readium's `content().elements()` iterates the entire publication. For a text-only extraction of a large book, holding all chapter text in memory simultaneously can exceed iOS app limits.

**How to avoid:**
- Extract text per chapter (use `publication.content(from: chapterLocator)` to scope extraction)
- Cache extracted text per chapter in memory, releasing chapters not currently being read
- Profile memory with large test EPUBs using Instruments

**Warning signs:** App killed by system (no crash log), works with small books but fails with large ones.

### Pitfall 5: Non-Deterministic Tokenization Breaking Saved Positions

**What goes wrong:** Reading position is saved as `(chapterIndex, wordIndex)`. If the tokenizer produces different word arrays for the same text across app versions (due to NLTokenizer behavior changes or locale differences), saved positions point to wrong words.

**Why it happens:** NLTokenizer's behavior can vary subtly between iOS versions and locale settings. Apple may change tokenization rules in iOS updates.

**How to avoid:**
- Store a small text snippet alongside the word index as a verification anchor (e.g., save the 3-word window around the position)
- On restore, verify the word at the saved index matches the snippet. If not, search nearby for the matching words.
- Pin NLTokenizer to a specific language (`.setLanguage(.english)`) rather than relying on auto-detection for consistency

**Warning signs:** After iOS update, users report being sent to wrong position in book. Different devices show different positions for the same book.

## Code Examples

### Opening an EPUB with Readium

```swift
// Source: Readium Swift Toolkit Context7 (/readium/swift-toolkit)
import ReadiumShared
import ReadiumStreamer

@Observable
final class EPUBParserService {
    private let httpClient = DefaultHTTPClient()
    private lazy var assetRetriever = AssetRetriever(httpClient: httpClient)
    private lazy var publicationOpener = PublicationOpener(
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        )
    )

    func openEPUB(at fileURL: URL) async throws -> Publication {
        let asset = try await assetRetriever.retrieve(url: fileURL)
        let result = await publicationOpener.open(
            asset: asset,
            allowUserInteraction: false,
            warnings: nil
        )
        switch result {
        case .success(let publication):
            return publication
        case .failure(let error):
            throw error
        }
    }
}
```

### Extracting Text Per Chapter

```swift
// Source: Readium Content Guide (Context7)
func extractChapters(from publication: Publication) -> [(title: String, text: String)] {
    var chapters: [(title: String, text: String)] = []

    for (index, link) in publication.tableOfContents.enumerated() {
        let title = link.title ?? "Chapter \(index + 1)"

        // Get content starting from this TOC entry's locator
        if let locator = publication.locator(for: link),
           let content = publication.content(from: locator) {
            let text = content.elements()
                .compactMap { ($0 as? TextualContentElement)?.text }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            chapters.append((title: title, text: text))
        }
    }

    return chapters
}
```

### Word Tokenization with NLTokenizer

```swift
// Source: Apple NLTokenizer documentation
import NaturalLanguage

struct WordToken {
    let index: Int
    let text: String
    let range: Range<String.Index>
    let isSentenceEnd: Bool
}

final class WordTokenizer {
    func tokenize(_ text: String) -> [WordToken] {
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = text
        wordTokenizer.setLanguage(.english)

        // First pass: get sentence boundaries
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        sentenceTokenizer.setLanguage(.english)

        var sentenceEnds: Set<String.Index> = []
        sentenceTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { range, _ in
            sentenceEnds.insert(range.upperBound)
            return true
        }

        // Second pass: get words with sentence boundary flags
        var tokens: [WordToken] = []
        var index = 0
        wordTokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { range, _ in
            let word = String(text[range])
            // Check if any sentence end falls within or at the end of this word range
            let isSentenceEnd = sentenceEnds.contains(where: {
                $0 >= range.lowerBound && $0 <= range.upperBound
            })
            tokens.append(WordToken(
                index: index,
                text: word,
                range: range,
                isSentenceEnd: isSentenceEnd
            ))
            index += 1
            return true
        }

        return tokens
    }
}
```

### File Import with Security-Scoped URL

```swift
// Source: Apple Developer Documentation, useyourloaf.com
import UniformTypeIdentifiers

@Observable
final class EPUBImportService {
    var isImporting = false
    var importError: String?

    func importEPUB(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        // Access security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Cannot access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Copy to app sandbox
            let booksDir = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!.appendingPathComponent("Books", isDirectory: true)

            try FileManager.default.createDirectory(
                at: booksDir, withIntermediateDirectories: true
            )

            let fileName = url.lastPathComponent
            let destination = booksDir.appendingPathComponent(fileName)

            // Remove existing file if re-importing
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(at: url, to: destination)

            // Now parse with Readium using the local copy
            // ... (EPUBParserService.openEPUB(at: destination))
        } catch {
            importError = "Failed to import: \(error.localizedDescription)"
        }
    }
}
```

### SwiftData ModelContainer Setup

```swift
// Source: Apple Developer Documentation (SwiftData + CloudKit)
import SwiftData
import SwiftUI

@main
struct BlazeBooksApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .private("iCloud.com.example.BlazeBooks")
            )
            modelContainer = try ModelContainer(
                for: SchemaV1.Book.self,
                    SchemaV1.Chapter.self,
                    SchemaV1.ReadingPosition.self,
                migrationPlan: BlazeBooksMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIDocumentPickerViewController with UIViewControllerRepresentable | SwiftUI `.fileImporter` modifier | iOS 14+ (2020) | No UIKit bridging needed. Native SwiftUI. |
| Core Data + NSPersistentCloudKitContainer | SwiftData + ModelConfiguration(cloudKitDatabase:) | iOS 17 (2023) | Dramatically less boilerplate. Same CloudKit constraints apply. |
| Manual EPUB unzip + XMLParser | Readium Swift Toolkit Content API | Readium 3.x (2023+) | `publication.content().elements()` replaces custom parsing pipelines. |
| String.split for tokenization | NLTokenizer (NaturalLanguage framework) | iOS 12+ (2018) | Language-aware, handles edge cases across 40+ languages. |
| ObservableObject + @Published (Combine) | @Observable macro (Observation framework) | iOS 17 (2023) | Less boilerplate, better performance (fine-grained tracking), no Combine needed. |
| VersionedSchema not available | VersionedSchema + SchemaMigrationPlan | iOS 17 (2023) | First-class schema versioning in SwiftData. Required for safe CloudKit migrations. |
| Readium 2.x (R2* prefixes, completion handlers) | Readium 3.7.0 (Readium* prefixes, async/await) | 2023-2026 | Modern Swift concurrency, cleaner API surface. Content API added. |

**Deprecated/outdated:**
- **FolioReaderKit:** Effectively unmaintained. UIKit-only. Do not use for new projects.
- **EPUBKit:** Metadata-only extraction. Author explicitly warns against use for larger projects.
- **Readium 2.x:** API prefixes changed from `R2*` to `Readium*`. Completion handlers replaced with async/await. Do not reference R2 APIs.

## Open Questions

1. **Readium Content API experimental status**
   - What we know: The Readium Content guide states "The described feature is still experimental and the implementation incomplete."
   - What's unclear: Which specific parts are incomplete. Text extraction via `TextualContentElement` appears to work based on the API documentation and code examples. Edge cases (e.g., heavily nested HTML, SVG-embedded text) may not be handled.
   - Recommendation: Use the Content API as primary extraction path. Build a fallback: if a chapter yields empty text, try accessing the raw resource via `publication.get(link)` and strip HTML with a basic regex as a last resort. Test with 20+ Gutenberg EPUBs to assess completeness.

2. **Chapter extraction scope with tableOfContents vs readingOrder**
   - What we know: `publication.tableOfContents` returns `[Link]` with titles and hrefs matching user-visible chapter structure. `publication.readingOrder` returns `[Link]` in spine order (every content document). Some EPUBs have empty or incomplete TOCs.
   - What's unclear: For EPUBs with no TOC entries, whether `readingOrder` can serve as a fallback chapter list.
   - Recommendation: Use `tableOfContents` as primary. If empty, fall back to `readingOrder` with auto-generated titles ("Section 1", "Section 2"). Log when fallback is used to assess frequency.

3. **NLTokenizer determinism across iOS versions**
   - What we know: NLTokenizer is language-aware and produces high-quality word boundaries. Behavior may vary between iOS versions.
   - What's unclear: Whether Apple guarantees stable tokenization output across iOS versions for the same input and language.
   - Recommendation: Store a verification snippet (3-5 words around saved position). On restore, verify match and search nearby if mismatched. This makes position tracking resilient to tokenizer changes.

## Sources

### Primary (HIGH confidence)
- `/readium/swift-toolkit` (Context7, benchmark 86.7, High reputation) -- EPUB opening, Content API, text extraction, tableOfContents, AssetRetriever/PublicationOpener pattern
- `/websites/developer_apple_swiftdata` (Context7, benchmark 76.3, High reputation) -- ModelConfiguration, CloudKit sync, VersionedSchema, SchemaMigrationPlan, MigrationStage
- [Apple UTType.epub documentation](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/epub) -- `UTType.epub` confirmation for `.fileImporter`
- [Apple NLTokenizer documentation](https://developer.apple.com/documentation/naturallanguage/nltokenizer) -- Tokenization units, enumerateTokens API
- [Apple fileImporter documentation](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)) -- SwiftUI native file import

### Secondary (MEDIUM confidence)
- [Readium Swift Toolkit GitHub README](https://github.com/readium/swift-toolkit) -- Confirmed 3.7.0 latest, iOS 15.0 minimum, Swift 5.10, SPM modules
- [Readium releases page](https://github.com/readium/swift-toolkit/releases) -- Version history, 3.7.0 released Feb 4, 2026
- [Readium Content Guide](https://github.com/readium/swift-toolkit/blob/develop/docs/Guides/Content.md) -- TextualContentElement, Content iterator, experimental status note
- [Hacking with Swift: SwiftData + CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit) -- Setup steps, entitlements, model rules
- [firewhale.io: SwiftData CloudKit quirks](https://firewhale.io/posts/swift-data-quirks/) -- Optional relationships workaround pattern
- [fatbobman.com: CloudKit model rules](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) -- Add-only schema, optional properties, no unique constraints
- [AzamSharp: VersionedSchema](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html) -- Why VersionedSchema from day one
- [useyourloaf.com: Security-scoped files](https://useyourloaf.com/blog/accessing-security-scoped-files/) -- Start/stop accessing pattern, defer cleanup
- [Andy Ibanez: NLTokenizer tutorial](https://www.andyibanez.com/posts/tokenizing-nltokenizer/) -- Word/sentence tokenization code examples
- [Tokenizing text with Natural Language](https://www.createwithswift.com/tokenizing-text-with-the-natural-language-framework/) -- NLTokenizer patterns

### Tertiary (LOW confidence)
- Readium Content API "experimental" status -- noted in docs but no specifics on what is incomplete. Needs validation through testing with diverse EPUBs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All libraries verified via Context7 and official docs. Readium 3.7.0 confirmed as latest. SwiftData + CloudKit patterns well-documented.
- Architecture: HIGH -- Patterns follow Apple's recommended @Observable + environment injection. VersionedSchema pattern from official docs. File import uses native SwiftUI API.
- Pitfalls: HIGH -- CloudKit constraints and EPUB malformation issues verified across multiple authoritative sources. Security-scoped URL pattern confirmed via Apple documentation.
- Code examples: MEDIUM-HIGH -- Readium content extraction API marked "experimental" but code patterns are from official guides. NLTokenizer patterns from Apple docs. SwiftData setup from official documentation.

**Research date:** 2026-02-20
**Valid until:** 2026-03-20 (stable ecosystem, 30-day validity)

---
*Phase 1 research for: Blaze Books -- EPUB import, parsing, tokenization, data models*
*Researched: 2026-02-20*
