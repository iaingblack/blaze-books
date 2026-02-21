# Phase 6: Book Discovery - Research

**Researched:** 2026-02-21
**Domain:** Project Gutenberg API integration, EPUB download, SwiftUI browse/grid UI
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Genre grid layout -- tap a genre card to see its books
- Genre cards show a small collage of 2-3 book covers from that genre with the genre name overlaid
- Books within a genre displayed as a book cover grid (matching the library layout style)
- Discovery accessed via a button/section within the Library view (not a separate tab)
- Minimal detail view: cover, title, author, and Download button
- Info button available to expand/reveal additional summary information
- Presented as a sheet (half/full) sliding up over the genre grid
- Books already in the user's library show an "In Library" badge instead of Download button
- Cover images sourced from Gutenberg metadata, with placeholder fallback
- Download button transforms into inline progress indicator, then shows "In Library" when complete
- No "Read Now" offer after download -- just confirms with the badge, user navigates to Library when ready
- Downloaded EPUBs go through the existing EPUB import pipeline (same parsing/chapter extraction)
- On network failure, show error state on the download button with a "Retry" option
- Live queries to Gutenberg API by genre/subject (not bundled JSON)
- Broad genre set (~12-15 categories): Fiction, Science Fiction, Mystery, Philosophy, Science, History, Poetry, Adventure, Biography, Drama, Horror, Children's, Religion, etc.
- Default sort by Gutenberg download count (most popular first), no additional sort options
- Infinite scroll within a genre (keep loading as user scrolls)
- English-language books only (matches RSVP reader's NLLanguage.english tokenization)

### Claude's Discretion
- Exact genre list and Gutenberg subject-to-genre mapping
- Genre card visual design details (shadows, corner radius, overlay styling)
- Loading/skeleton states while API responses arrive
- Caching strategy for API responses
- Exact Gutenberg API endpoint selection and pagination implementation

### Deferred Ideas (OUT OF SCOPE)
- DISC-03: Full-text search of Project Gutenberg catalog -- backlog item, not in v1.0 scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DISC-01 | User can browse curated Project Gutenberg collections by genre | Gutendex API `topic` parameter maps genres to bookshelf/subject queries; genre-to-topic mapping table defined; pagination via `next` URLs; AsyncImage for covers |
| DISC-02 | User can download free books from Gutenberg directly in-app | EPUB URL from `formats["application/epub+zip"]`; URLSession.shared.download for file fetch; feed into existing EPUBImportService pipeline; duplicate detection via fileHash |
</phase_requirements>

## Summary

This phase adds a book discovery feature that lets users browse curated Project Gutenberg genre collections and download free public domain EPUBs directly into their library. The technical stack is straightforward: the Gutendex API (gutendex.com) provides a JSON REST API for querying the Project Gutenberg catalog with genre/topic filtering, and Gutenberg.org hosts the EPUB files for direct download. Multiple production iOS and Android apps (e.g., "Gutenberg Reader", "Myne") already use this exact pattern successfully.

The Gutendex API requires no authentication, returns paginated JSON with 32 results per page, supports a `topic` parameter for genre-based filtering, and includes EPUB download URLs in each book's `formats` dictionary. The existing EPUBImportService can be refactored to accept a local file URL (bypassing the security-scoped resource access needed for Files picker imports) to handle downloaded EPUBs identically to user-imported ones. Cover images are available as JPEG URLs in the API response.

The primary technical decisions are: (1) defining the genre-to-Gutendex-topic mapping, (2) building a lightweight networking layer for API calls and file downloads, (3) implementing infinite scroll pagination in a LazyVGrid, and (4) integrating downloaded files into the existing EPUB import pipeline.

**Primary recommendation:** Use Gutendex API at gutendex.com/books with `topic` + `languages=en` parameters for genre browsing, `application/epub+zip` format URLs for downloads, and refactor EPUBImportService to separate file-picker concerns from core import logic so downloaded EPUBs share the same pipeline.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| URLSession | iOS 17+ | HTTP requests (API + file downloads) | Built-in, async/await support, no dependency needed |
| JSONDecoder | Foundation | Parse Gutendex API responses | Built-in Codable decoding |
| AsyncImage | SwiftUI | Load cover images from Gutenberg URLs | Built-in SwiftUI, uses URLCache underneath |
| FileManager | Foundation | Move downloaded EPUB to sandbox | Built-in, same as existing import flow |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Readium (existing) | Already in project | Parse downloaded EPUB files | Reuse existing EPUBParserService for chapter extraction |
| CryptoKit (existing) | Already in project | Compute file hash for duplicate detection | Reuse existing FileStorageManager.computeFileHash |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AsyncImage | Kingfisher/Nuke | Better caching, but adds dependency for a feature that only loads small cover thumbnails |
| URLSession | Alamofire | More features, but URLSession async/await is sufficient for simple REST + file download |
| Gutendex public instance | Self-hosted Gutendex | No rate limit concerns, but overkill for a reading app with moderate API usage |

**No additional dependencies required.** Everything needed is already in the project or available via Foundation/SwiftUI.

## Architecture Patterns

### Recommended Project Structure
```
BlazeBooks/
├── Services/
│   ├── GutendexService.swift          # API client for Gutendex REST API
│   ├── BookDownloadService.swift       # EPUB download + import orchestration
│   └── EPUBImportService.swift         # MODIFIED: extract reusable import method
├── Models/
│   └── GutendexModels.swift            # Codable structs for API responses
├── Views/
│   └── Discovery/
│       ├── DiscoveryView.swift         # Genre grid (entry point)
│       ├── GenreCardView.swift         # Individual genre card with cover collage
│       ├── GenreBooksView.swift        # Book grid for a selected genre (infinite scroll)
│       └── BookDetailSheet.swift       # Sheet with cover, title, author, download button
```

### Pattern 1: GutendexService as @Observable API Client
**What:** A single @Observable service that manages API state (loading, error, results) and provides async methods for fetching books by genre with pagination.
**When to use:** All Gutendex API interactions.
**Example:**
```swift
// Based on project patterns: @Observable class, similar to EPUBImportService
@MainActor
@Observable
final class GutendexService {
    var isLoading = false
    var error: String?

    private let baseURL = "https://gutendex.com/books"
    private var cache: [String: CachedResponse] = [:]

    struct CachedResponse {
        let response: GutendexResponse
        let timestamp: Date
    }

    func fetchBooks(topic: String, page: Int = 1) async -> GutendexResponse? {
        let cacheKey = "\(topic)-\(page)"
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < 300 { // 5 min cache
            return cached.response
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "topic", value: topic),
            URLQueryItem(name: "languages", value: "en"),
            URLQueryItem(name: "mime_type", value: "application/epub"),
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GutendexResponse.self, from: data)
            cache[cacheKey] = CachedResponse(response: response, timestamp: Date())
            return response
        } catch {
            self.error = "Could not load books. Check your connection."
            return nil
        }
    }
}
```

### Pattern 2: Codable Models for Gutendex API
**What:** Lightweight Codable structs matching the Gutendex JSON response format.
**When to use:** Decoding API responses.
**Example:**
```swift
// Source: Verified against gutendex.com/books/84 response
struct GutendexResponse: Codable {
    let count: Int
    let next: String?        // URL for next page, nil if last page
    let previous: String?
    let results: [GutendexBook]
}

struct GutendexBook: Codable, Identifiable {
    let id: Int              // Project Gutenberg ID
    let title: String
    let authors: [GutendexPerson]
    let subjects: [String]
    let bookshelves: [String]
    let languages: [String]
    let copyright: Bool?
    let mediaType: String
    let formats: [String: String]    // MIME type -> download URL
    let downloadCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, authors, subjects, bookshelves, languages
        case copyright, formats
        case mediaType = "media_type"
        case downloadCount = "download_count"
    }

    /// EPUB download URL from formats dictionary
    var epubURL: URL? {
        guard let urlString = formats["application/epub+zip"] else { return nil }
        return URL(string: urlString)
    }

    /// Cover image URL from formats dictionary
    var coverImageURL: URL? {
        guard let urlString = formats["image/jpeg"] else { return nil }
        return URL(string: urlString)
    }

    /// Primary author name (formatted as "First Last" from Gutenberg's "Last, First")
    var primaryAuthor: String {
        guard let author = authors.first else { return "Unknown Author" }
        let parts = author.name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            return "\(parts[1]) \(parts[0])"
        }
        return author.name
    }
}

struct GutendexPerson: Codable {
    let name: String
    let birthYear: Int?
    let deathYear: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case birthYear = "birth_year"
        case deathYear = "death_year"
    }
}
```

### Pattern 3: Download + Import Pipeline Integration
**What:** BookDownloadService downloads EPUB to sandbox, then calls a refactored EPUBImportService method.
**When to use:** When user taps Download on a Gutenberg book.
**Example:**
```swift
@MainActor
@Observable
final class BookDownloadService {
    // Track per-book download state by Gutenberg ID
    var activeDownloads: [Int: DownloadState] = [:]

    enum DownloadState {
        case downloading(progress: Double)
        case importing
        case completed
        case failed(String)
    }

    func downloadBook(_ gutendexBook: GutendexBook, modelContext: ModelContext) async {
        guard let epubURL = gutendexBook.epubURL else {
            activeDownloads[gutendexBook.id] = .failed("No EPUB available")
            return
        }

        activeDownloads[gutendexBook.id] = .downloading(progress: 0)

        do {
            // 1. Download EPUB to temporary location
            let (tempURL, _) = try await URLSession.shared.download(from: epubURL)

            // 2. Move to app sandbox (Documents/Books/)
            let fileName = "\(gutendexBook.id).epub"
            let destinationURL = FileStorageManager.booksDirectory
                .appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // 3. Import via existing pipeline
            activeDownloads[gutendexBook.id] = .importing
            try await importDownloadedEPUB(
                at: destinationURL,
                gutendexBook: gutendexBook,
                modelContext: modelContext
            )

            activeDownloads[gutendexBook.id] = .completed
        } catch {
            activeDownloads[gutendexBook.id] = .failed("Download failed. Tap to retry.")
        }
    }
}
```

### Pattern 4: Infinite Scroll Pagination
**What:** Detect when user scrolls near the end of results and load the next page.
**When to use:** GenreBooksView displaying books within a selected genre.
**Example:**
```swift
// In GenreBooksView
LazyVGrid(columns: columns, spacing: 20) {
    ForEach(books) { book in
        BookDiscoveryCard(book: book)
            .onAppear {
                if book.id == books.last?.id {
                    Task { await loadNextPage() }
                }
            }
    }
}
// Pagination uses the `next` URL from GutendexResponse
// which includes the correct page parameter automatically
```

### Pattern 5: "In Library" Detection
**What:** Check if a Gutenberg book already exists in the user's SwiftData library by matching Gutenberg ID stored in the book record or by matching title+author.
**When to use:** Displaying "In Library" badge vs Download button.
**Example:**
```swift
// Option A: Store gutenbergId on Book model (recommended -- precise matching)
// Add optional gutenbergId: Int? to SchemaV3.Book

// Option B: Match by title+author (works without schema change, less precise)
func isInLibrary(_ gutendexBook: GutendexBook, existingBooks: [Book]) -> Bool {
    existingBooks.contains { book in
        book.title.lowercased() == gutendexBook.title.lowercased()
    }
}
```

### Anti-Patterns to Avoid
- **Scraping Gutenberg.org HTML pages:** Use the Gutendex API, which exists specifically for programmatic access. Gutenberg.org blocks automated web page access.
- **Downloading all genre data upfront:** Use lazy pagination (32 items per page). Gutenberg has thousands of books per genre.
- **Creating a separate navigation tab for discovery:** User decision locks this to a button/section within the Library view.
- **Bypassing the EPUB import pipeline:** Downloaded EPUBs MUST go through the same parsing pipeline as file-imported EPUBs to ensure chapters, tokenization, and reading positions work identically.
- **Storing cover images from API in SwiftData:** Use AsyncImage for browsing cover thumbnails (ephemeral). Only persist cover data after download via the existing EPUB parsing pipeline.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Remote image loading | Custom URLSession image loader | SwiftUI AsyncImage | Built-in, handles loading/error states, uses URLCache |
| JSON API decoding | Manual JSON parsing | Codable + JSONDecoder | Type-safe, less error-prone, standard Swift pattern |
| EPUB parsing | Custom EPUB extraction | Existing EPUBParserService (Readium) | Already battle-tested in the project, handles edge cases |
| File hash computation | Custom hashing | Existing FileStorageManager.computeFileHash | SHA256 via CryptoKit, already working |
| URL pagination | Custom page counter | Use `next` URL from Gutendex response | API provides ready-made next page URL |

**Key insight:** The entire download-to-library pipeline can be built by composing URLSession.download + FileManager.moveItem + the existing EPUBImportService. No new parsing logic is needed.

## Common Pitfalls

### Pitfall 1: Gutenberg.org Robot Access Blocking
**What goes wrong:** Gutenberg.org blocks IP addresses that make automated requests to their website HTML pages.
**Why it happens:** Their policy states "The Project Gutenberg website is intended for human users only."
**How to avoid:** Use Gutendex API (gutendex.com) for all catalog/metadata queries. EPUB file download URLs (e.g., `gutenberg.org/ebooks/84.epub3.images`) are direct file links, not web pages -- these are used by multiple existing iOS/Android apps without issues. The robot policy targets web page scraping, not file downloads from known URLs.
**Warning signs:** HTTP 403 or connection refused errors from gutenberg.org.

### Pitfall 2: Gutendex Public Instance Rate Limits
**What goes wrong:** Too many rapid API calls get throttled (60 requests/minute/IP reported).
**Why it happens:** The public gutendex.com instance is a free service not intended for heavy production use.
**How to avoid:** Implement a 5-minute in-memory cache for API responses. Users browse genres sequentially (not 60 parallel requests). Pagination loads one page at a time on scroll. Normal usage pattern will stay well within limits.
**Warning signs:** HTTP 429 responses or slow/timeout responses from gutendex.com.

### Pitfall 3: Missing EPUB Format in Gutendex Results
**What goes wrong:** Some Gutenberg books don't have an EPUB format available (only plain text or HTML).
**Why it happens:** Not all books have been processed into EPUB format by Gutenberg's ebookmaker tool.
**How to avoid:** Filter with `mime_type=application/epub` query parameter to only get books with EPUB format. Also check `formats["application/epub+zip"]` is non-nil before showing the Download button.
**Warning signs:** Download button shown for book that has no EPUB URL, leading to nil URL crash.

### Pitfall 4: URLSession Download Temporary File Lifetime
**What goes wrong:** The temporary file from URLSession.download is deleted by the system before you move it.
**Why it happens:** iOS cleans up temporary files aggressively. The temp file is only guaranteed to exist until you return from the completion context.
**How to avoid:** Move the file to the permanent sandbox location (Documents/Books/) immediately after the download completes, before any other async work.
**Warning signs:** "File not found" errors when trying to parse the downloaded EPUB.

### Pitfall 5: Duplicate Book Detection for Downloads
**What goes wrong:** User downloads the same book twice, creating duplicates in the library.
**Why it happens:** The existing duplicate detection uses file hash, but the same Gutenberg EPUB downloaded twice will have the same hash.
**How to avoid:** Check for duplicates BEFORE downloading: either by storing gutenbergId on the Book model, or by checking file hash after download but before creating SwiftData records (the existing EPUBImportService already does hash-based duplicate detection).
**Warning signs:** Same book appearing multiple times in the library after re-downloading.

### Pitfall 6: Author Name Format Mismatch
**What goes wrong:** Gutenberg uses "Last, First" format (e.g., "Shelley, Mary Wollstonecraft") while the library displays author names.
**Why it happens:** Gutenberg's metadata convention differs from typical display format.
**How to avoid:** Convert "Last, First" to "First Last" when displaying in the discovery UI and when creating the Book record from a download. The `primaryAuthor` computed property in GutendexBook handles this.
**Warning signs:** Author names showing as "Shelley, Mary Wollstonecraft" instead of "Mary Wollstonecraft Shelley" in the UI.

### Pitfall 7: Genre Cover Collage Requires Pre-fetching
**What goes wrong:** Genre cards need 2-3 cover images to display, but you don't have any book data until the user opens a genre.
**Why it happens:** The genre grid is the first screen -- you need cover images before the user has selected any genre.
**How to avoid:** On DiscoveryView appear, fire parallel requests for each genre (just page 1) to populate cover image URLs. Cache these responses. Use a loading/skeleton state while the initial batch loads.
**Warning signs:** Blank genre cards with no cover images, or genre grid appearing empty on first load.

### Pitfall 8: SwiftData Schema Migration for gutenbergId
**What goes wrong:** Adding a new field to the Book model requires a schema migration.
**Why it happens:** SwiftData requires versioned schemas when adding new properties.
**How to avoid:** If adding `gutenbergId: Int?` to Book, create a SchemaV3 with a lightweight migration plan. Since it's optional with nil default, the migration is automatic (additive). Alternatively, skip the schema change and use title-matching for "In Library" detection, which is less precise but avoids migration.
**Warning signs:** App crashes on launch after adding a field without migration.

## Code Examples

Verified patterns from official sources and existing codebase:

### Gutendex API Request
```swift
// Source: Verified against gutendex.com API documentation
// GET https://gutendex.com/books?topic=science+fiction&languages=en&mime_type=application/epub
// Returns: { "count": 742, "next": "...?page=2", "results": [...] }

func fetchBooks(topic: String, page: Int = 1) async throws -> GutendexResponse {
    var components = URLComponents(string: "https://gutendex.com/books")!
    components.queryItems = [
        URLQueryItem(name: "topic", value: topic),
        URLQueryItem(name: "languages", value: "en"),
        URLQueryItem(name: "mime_type", value: "application/epub"),
        URLQueryItem(name: "page", value: String(page))
    ]
    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw GutendexError.requestFailed
    }
    return try JSONDecoder().decode(GutendexResponse.self, from: data)
}
```

### Genre-to-Topic Mapping (Recommended)
```swift
// Source: Verified against Gutenberg bookshelves at gutenberg.org/ebooks/bookshelves/search/
// The `topic` parameter searches both bookshelves and subjects case-insensitively
struct Genre: Identifiable {
    let id = UUID()
    let name: String           // Display name
    let topic: String          // Gutendex API topic parameter value
    let systemImage: String    // SF Symbol for fallback/decoration

    static let all: [Genre] = [
        Genre(name: "Fiction", topic: "fiction", systemImage: "book"),
        Genre(name: "Science Fiction", topic: "science fiction", systemImage: "sparkles"),
        Genre(name: "Mystery", topic: "mystery", systemImage: "magnifyingglass"),
        Genre(name: "Adventure", topic: "adventure", systemImage: "figure.hiking"),
        Genre(name: "Romance", topic: "romance", systemImage: "heart"),
        Genre(name: "Horror", topic: "horror", systemImage: "moon.stars"),
        Genre(name: "Philosophy", topic: "philosophy", systemImage: "brain.head.profile"),
        Genre(name: "Poetry", topic: "poetry", systemImage: "text.quote"),
        Genre(name: "History", topic: "history", systemImage: "clock.arrow.circlepath"),
        Genre(name: "Biography", topic: "biography", systemImage: "person"),
        Genre(name: "Science", topic: "science", systemImage: "atom"),
        Genre(name: "Children's", topic: "children", systemImage: "face.smiling"),
        Genre(name: "Short Stories", topic: "short stories", systemImage: "text.alignleft"),
        Genre(name: "Drama", topic: "drama", systemImage: "theatermasks"),
    ]
}
```

### EPUB Download and Import
```swift
// Source: Based on existing EPUBImportService pattern + URLSession download API
func downloadAndImport(_ book: GutendexBook, modelContext: ModelContext) async throws {
    guard let epubURL = book.epubURL else {
        throw DownloadError.noEPUBAvailable
    }

    // 1. Download to temp file
    let (tempURL, _) = try await URLSession.shared.download(from: epubURL)

    // 2. Move to sandbox
    let fileName = "gutenberg-\(book.id).epub"
    let localURL = FileStorageManager.booksDirectory.appendingPathComponent(fileName)
    if FileManager.default.fileExists(atPath: localURL.path) {
        try FileManager.default.removeItem(at: localURL)
    }
    try FileManager.default.moveItem(at: tempURL, to: localURL)

    // 3. Check for duplicate by file hash
    let fileHash = try FileStorageManager.computeFileHash(at: localURL)
    let fetchDescriptor = FetchDescriptor<Book>(
        predicate: #Predicate<Book> { $0.fileHash == fileHash }
    )
    if !(try modelContext.fetch(fetchDescriptor)).isEmpty {
        try? FileManager.default.removeItem(at: localURL)
        throw DownloadError.alreadyInLibrary
    }

    // 4. Parse with existing Readium pipeline
    let parserService = EPUBParserService()
    let parsedBook = try await parserService.parseEPUB(at: localURL)

    // 5. Create Book record (reuse same logic as EPUBImportService)
    let title = parsedBook.title.isEmpty ? book.title : parsedBook.title
    let author = parsedBook.author.isEmpty ? book.primaryAuthor : parsedBook.author
    let newBook = Book(
        title: title,
        author: author,
        filePath: fileName,
        coverImageData: parsedBook.coverData,
        fileHash: fileHash
    )
    // ... create chapters and reading position (same as EPUBImportService)
}
```

### AsyncImage Cover Loading with Placeholder
```swift
// Source: SwiftUI AsyncImage documentation
// Reuses existing BookCoverView placeholder gradient pattern
if let coverURL = gutendexBook.coverImageURL {
    AsyncImage(url: coverURL) { phase in
        switch phase {
        case .success(let image):
            image
                .resizable()
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .clipped()
        case .failure:
            placeholderCover(title: gutendexBook.title)
        case .empty:
            ProgressView()
        @unknown default:
            placeholderCover(title: gutendexBook.title)
        }
    }
    .aspectRatio(2.0 / 3.0, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

### Book Detail Sheet
```swift
// Source: User decision -- sheet presentation, minimal detail view
.sheet(item: $selectedBook) { book in
    BookDetailSheet(
        book: book,
        isInLibrary: isInLibrary(book),
        downloadState: downloadService.activeDownloads[book.id],
        onDownload: {
            Task {
                await downloadService.downloadBook(book, modelContext: modelContext)
            }
        }
    )
    .presentationDetents([.medium, .large])
}
```

## Gutendex API Reference (Verified)

### Endpoint
`GET https://gutendex.com/books`

### Query Parameters Used
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `topic` | genre keyword (e.g., "science fiction") | Case-insensitive search in bookshelves and subjects |
| `languages` | `en` | English-only books |
| `mime_type` | `application/epub` | Only books with EPUB format available |
| `page` | integer | Pagination (32 results per page) |

### Response Format (Verified against live API)
```json
{
    "count": 742,
    "next": "https://gutendex.com/books?languages=en&mime_type=application%2Fepub&page=2&topic=science+fiction",
    "previous": null,
    "results": [
        {
            "id": 84,
            "title": "Frankenstein; or, the modern prometheus",
            "authors": [{ "name": "Shelley, Mary Wollstonecraft", "birth_year": 1797, "death_year": 1851 }],
            "subjects": ["Gothic fiction", "Horror tales", "Science fiction"],
            "bookshelves": ["Gothic Fiction", "Science Fiction by Women"],
            "languages": ["en"],
            "copyright": false,
            "media_type": "Text",
            "formats": {
                "application/epub+zip": "https://www.gutenberg.org/ebooks/84.epub3.images",
                "image/jpeg": "https://www.gutenberg.org/cache/epub/84/pg84.cover.medium.jpg",
                "text/html": "https://www.gutenberg.org/ebooks/84.html.images",
                "text/plain; charset=utf-8": "https://www.gutenberg.org/ebooks/84.txt.utf-8"
            },
            "download_count": 150546
        }
    ]
}
```

### Key URL Patterns
- EPUB download: `https://www.gutenberg.org/ebooks/{id}.epub3.images`
- Cover image: `https://www.gutenberg.org/cache/epub/{id}/pg{id}.cover.medium.jpg`
- Individual book lookup: `https://gutendex.com/books/{id}`

## EPUBImportService Refactoring Strategy

The existing `EPUBImportService.importEPUB(from:modelContext:)` is tightly coupled to the file-picker flow (security-scoped resource access, copy to sandbox). For downloaded EPUBs, we need to skip steps 1 (security-scoped access) and 4 (copy to sandbox -- file is already there).

**Recommended approach:** Extract the core import logic (hash check, parse, create records) into a shared method, then call it from both the existing file-picker flow and the new download flow.

```swift
// Current: importEPUB(from url: URL, modelContext: ModelContext) -- file picker entry
// New:     importLocalEPUB(at localURL: URL, modelContext: ModelContext) -- core logic
//          Both use the same parse + create records logic
```

This avoids duplicating the Book/Chapter/ReadingPosition creation logic across two services.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bundled JSON catalogs | Live API queries via Gutendex | 2021+ | Fresh data, no app update needed for new books |
| URLSession completion handlers | async/await download(from:) | iOS 15+ / Swift 5.5 | Cleaner code, structured concurrency |
| Custom image loading | SwiftUI AsyncImage | iOS 15+ | Built-in, no third-party dependency |
| Multiple EPUB formats | epub3.images as standard | 2020+ | Modern EPUB3 with embedded images |

**Deprecated/outdated:**
- epub.images (EPUB2 format) -- Gutenberg now generates epub3.images as primary
- Custom NSURLSession delegate for simple downloads -- async/await preferred

## Open Questions

1. **Gutendex Public Instance Reliability**
   - What we know: gutendex.com is a free public instance; multiple apps use it; 60 req/min rate limit reported
   - What's unclear: Long-term availability guarantees; whether the instance has had outages
   - Recommendation: Use it for v1. Implement graceful error handling. If it proves unreliable, self-hosting is an option (Django app, documented on GitHub). Caching reduces dependency.

2. **Genre Cover Collage Performance**
   - What we know: Need 2-3 cover images per genre card (14 genres = 28-42 image URLs needed on first load)
   - What's unclear: Whether fetching 14 genre pages simultaneously will be too slow or trigger rate limits
   - Recommendation: Fetch genre data in batches (e.g., 4-5 genres at a time) or accept a staggered loading experience where genre cards populate as their data arrives. Show skeleton/loading state per card.

3. **Schema Migration Decision: gutenbergId**
   - What we know: Adding `gutenbergId: Int?` to Book enables precise "In Library" detection without title-matching ambiguity
   - What's unclear: Whether the schema migration complexity is worth it vs. title+author matching
   - Recommendation: Add gutenbergId in a SchemaV3. It's a lightweight migration (additive optional field). It also future-proofs for DISC-03 search feature where knowing the Gutenberg ID would be valuable.

## Sources

### Primary (HIGH confidence)
- [Gutendex API](https://gutendex.com) -- API documentation, verified response format against live `/books/84` endpoint
- [Gutendex GitHub](https://github.com/garethbjohnson/gutendex) -- Source code and README with complete parameter documentation
- [Project Gutenberg Bookshelves](https://www.gutenberg.org/ebooks/bookshelves/search/) -- Verified bookshelf names for genre mapping
- Existing codebase -- EPUBImportService.swift, EPUBParserService.swift, FileStorageManager.swift, BookCoverView.swift, LibraryView.swift

### Secondary (MEDIUM confidence)
- [Project Gutenberg Robot Access Policy](https://www.gutenberg.org/policy/robot_access.html) -- Automated access rules; EPUB file downloads (not web page scraping) are used by existing iOS apps
- [Myne Android App](https://github.com/Pool-Of-Tears/Myne) -- Production Android app using Gutendex API pattern, validates the approach
- Multiple WebSearch results confirming AsyncImage caching behavior, URLSession download patterns

### Tertiary (LOW confidence)
- Gutendex rate limit of 60 req/min/IP -- reported by third-party API directories, not in official docs. Treat as approximate.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies needed; URLSession + Codable + AsyncImage are standard Swift patterns
- Architecture: HIGH -- Gutendex API verified against live endpoint; response format confirmed; genre/topic mapping tested
- Pitfalls: HIGH -- Robot access policy verified; rate limits documented; schema migration path clear
- Download pipeline: HIGH -- URLSession.download + existing EPUBImportService refactoring is straightforward

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (Gutendex API is stable; 30 days reasonable)
