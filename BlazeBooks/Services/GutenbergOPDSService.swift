import Foundation

/// Searches Project Gutenberg's official OPDS (Open Publication Distribution System) feed.
/// ~17x faster than the Gutendex third-party API (0.4s vs 7s TTFB) because it uses
/// PG's own optimized database rather than a separate full-text search service.
///
/// Used for the Discover tab's search bar. Genre browsing stays on Gutendex (already fast).
@MainActor
@Observable
final class GutenbergOPDSService {
    var isLoading = false
    var error: String?

    private var cache: [String: CachedResult] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "BlazeBooks/1.0 (iOS; Project Gutenberg OPDS client)"
        ]
        return URLSession(configuration: config)
    }()

    private struct CachedResult {
        let books: [GutendexBook]
        let nextPageURL: String?
        let timestamp: Date
    }

    struct SearchResult {
        let books: [GutendexBook]
        let nextPageURL: String?
    }

    func searchBooks(query: String) async -> SearchResult? {
        let cacheKey = "search-\(query)"

        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return SearchResult(books: cached.books, nextPageURL: cached.nextPageURL)
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        guard var components = URLComponents(string: "https://www.gutenberg.org/ebooks/search.opds/") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]

        guard let url = components.url else { return nil }
        return await fetchAndParse(url: url, cacheKey: cacheKey)
    }

    func fetchNextPage(from nextURL: String) async -> SearchResult? {
        if let cached = cache[nextURL],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return SearchResult(books: cached.books, nextPageURL: cached.nextPageURL)
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: nextURL) else { return nil }
        return await fetchAndParse(url: url, cacheKey: nextURL)
    }

    private func fetchAndParse(url: URL, cacheKey: String) async -> SearchResult? {
        do {
            let (data, _) = try await session.data(from: url)
            let parser = OPDSFeedParser(data: data)
            let entries = parser.parse()

            let books = entries.compactMap { entry -> GutendexBook? in
                guard let id = entry.bookID else { return nil }
                return GutendexBook(id: id, title: entry.title, authorName: entry.author)
            }

            let result = SearchResult(books: books, nextPageURL: parser.nextPageURL)
            cache[cacheKey] = CachedResult(books: books, nextPageURL: parser.nextPageURL, timestamp: Date())
            return result
        } catch is CancellationError {
            return nil
        } catch {
            self.error = "Could not load books. Check your connection."
            return nil
        }
    }
}

// MARK: - OPDS Atom/XML Parser

/// Parses Project Gutenberg's OPDS Atom XML feed into book entries.
/// Uses Foundation's XMLParser (no third-party dependencies).
private class OPDSFeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private(set) var nextPageURL: String?

    private var entries: [OPDSEntry] = []
    private var currentEntry: OPDSEntry?
    private var currentElement = ""
    private var currentText = ""
    private var insideAuthor = false

    struct OPDSEntry {
        var id = ""
        var title = ""
        var author = "Unknown Author"

        /// Extracts the numeric book ID from the OPDS entry ID URL.
        /// Format: "https://www.gutenberg.org/ebooks/1342" → 1342
        var bookID: Int? {
            guard let lastComponent = id.split(separator: "/").last else { return nil }
            return Int(lastComponent)
        }
    }

    init(data: Data) {
        self.data = data
    }

    func parse() -> [OPDSEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        // OPDS feeds include 2 meta-entries at the top (Authors/Subjects facets)
        // that aren't actual books — they have no numeric book ID.
        // The compactMap in the caller filters these out via bookID == nil.
        return entries
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        currentElement = elementName
        currentText = ""

        if elementName == "entry" {
            currentEntry = OPDSEntry()
        } else if elementName == "name" && currentEntry != nil {
            insideAuthor = true
        } else if elementName == "link" && currentEntry == nil {
            // Feed-level link — check for pagination
            if attributes["rel"] == "next",
               let href = attributes["href"] {
                if href.hasPrefix("http") {
                    nextPageURL = href
                } else {
                    nextPageURL = "https://www.gutenberg.org\(href)"
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard currentEntry != nil else { return }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "id":
            if currentEntry?.id.isEmpty == true {
                currentEntry?.id = text
            }
        case "title":
            if currentEntry?.title.isEmpty == true {
                currentEntry?.title = text
            }
        case "name":
            if insideAuthor {
                currentEntry?.author = text
                insideAuthor = false
            }
        case "entry":
            if let entry = currentEntry {
                entries.append(entry)
            }
            currentEntry = nil
        default:
            break
        }

        currentText = ""
    }
}
