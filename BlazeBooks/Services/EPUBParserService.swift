import Foundation
import Observation
import ReadiumShared
import ReadiumStreamer
import UIKit

/// Wraps the Readium Swift Toolkit for EPUB parsing and text extraction.
///
/// Opens EPUB files, extracts metadata (title, author, cover), iterates chapters
/// from the table of contents (with readingOrder fallback), and tokenizes chapter
/// text using `WordTokenizer`.
@Observable
final class EPUBParserService {

    // MARK: - Observable State

    var isParsing: Bool = false
    var parseProgress: Double = 0.0

    // MARK: - Parsed Data Types

    struct ParsedBook {
        let title: String
        let author: String
        let coverData: Data?
        let chapters: [ParsedChapter]
    }

    struct ParsedChapter {
        let title: String
        let index: Int
        let text: String
        let tokens: [WordToken]
        let parseError: Bool
    }

    // MARK: - Readium Components (excluded from observation tracking)

    @ObservationIgnored
    private var _httpClient: DefaultHTTPClient?

    @ObservationIgnored
    private var _assetRetriever: AssetRetriever?

    @ObservationIgnored
    private var _publicationOpener: PublicationOpener?

    private var httpClient: DefaultHTTPClient {
        if let client = _httpClient { return client }
        let client = DefaultHTTPClient()
        _httpClient = client
        return client
    }

    private var assetRetriever: AssetRetriever {
        if let retriever = _assetRetriever { return retriever }
        let retriever = AssetRetriever(httpClient: httpClient)
        _assetRetriever = retriever
        return retriever
    }

    private var publicationOpener: PublicationOpener {
        if let opener = _publicationOpener { return opener }
        let opener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            )
        )
        _publicationOpener = opener
        return opener
    }

    // MARK: - Tokenizer

    @ObservationIgnored
    private let tokenizer = WordTokenizer()

    // MARK: - Public API

    /// Opens an EPUB file at the given local file URL and returns the Readium `Publication`.
    func openEPUB(at fileURL: URL) async throws -> Publication {
        guard let absoluteURL = FileURL(url: fileURL) else {
            throw EPUBParseError.invalidURL
        }

        let assetResult = await assetRetriever.retrieve(url: absoluteURL)
        let asset: Asset
        switch assetResult {
        case .success(let a):
            asset = a
        case .failure(let error):
            throw EPUBParseError.assetRetrievalFailed(error)
        }

        let result = await publicationOpener.open(
            asset: asset,
            allowUserInteraction: false
        )

        switch result {
        case .success(let publication):
            return publication
        case .failure(let error):
            throw EPUBParseError.openFailed(error)
        }
    }

    /// Parses an EPUB at the given local file URL, extracting metadata, chapters, and tokenized text.
    ///
    /// - Returns: A `ParsedBook` with all extracted data.
    /// - Throws: `EPUBParseError` if the EPUB cannot be opened at all (completely corrupted/encrypted).
    func parseEPUB(at fileURL: URL) async throws -> ParsedBook {
        isParsing = true
        parseProgress = 0.0
        defer {
            isParsing = false
            parseProgress = 1.0
        }

        let publication = try await openEPUB(at: fileURL)

        // Extract metadata
        let title = publication.metadata.title ?? ""
        let author = publication.metadata.authors.first?.name ?? ""

        // Extract cover image
        let coverData = await extractCoverData(from: publication)

        // Extract chapters
        let chapters = await extractChapters(from: publication)

        return ParsedBook(
            title: title,
            author: author,
            coverData: coverData,
            chapters: chapters
        )
    }

    // MARK: - Private Helpers

    /// Extracts the cover image as JPEG data from the publication.
    private func extractCoverData(from publication: Publication) async -> Data? {
        let coverResult = await publication.cover()
        switch coverResult {
        case .success(let image):
            return image?.jpegData(compressionQuality: 0.8)
        case .failure:
            return nil
        }
    }

    /// Extracts chapters from the publication's table of contents, falling back to readingOrder.
    private func extractChapters(from publication: Publication) async -> [ParsedChapter] {
        // Try table of contents first
        let tocResult = await publication.tableOfContents()
        var links: [Link]
        var useFallbackTitles = false

        switch tocResult {
        case .success(let tocLinks) where !tocLinks.isEmpty:
            links = tocLinks
        default:
            // Fallback to readingOrder with auto-generated titles
            links = publication.readingOrder
            useFallbackTitles = true
        }

        guard !links.isEmpty else {
            return []
        }

        var chapters: [ParsedChapter] = []
        let totalChapters = links.count

        for (index, link) in links.enumerated() {
            let chapterTitle: String
            if useFallbackTitles {
                chapterTitle = "Section \(index + 1)"
            } else {
                chapterTitle = link.title ?? "Chapter \(index + 1)"
            }

            let chapter = await extractChapter(
                from: publication,
                link: link,
                title: chapterTitle,
                index: index
            )
            chapters.append(chapter)

            // Update progress
            parseProgress = Double(index + 1) / Double(totalChapters)
        }

        return chapters
    }

    /// Extracts a single chapter's text and tokenizes it.
    private func extractChapter(
        from publication: Publication,
        link: Link,
        title: String,
        index: Int
    ) async -> ParsedChapter {
        // Try the Content API first (primary extraction path)
        let text = await extractTextViaContentAPI(from: publication, link: link)

        if let text = text, !text.isEmpty {
            let tokens = tokenizer.tokenize(text)
            return ParsedChapter(
                title: title,
                index: index,
                text: text,
                tokens: tokens,
                parseError: false
            )
        }

        // Fallback: try raw resource access with basic HTML stripping
        let fallbackText = await extractTextViaRawResource(from: publication, link: link)

        if let fallbackText = fallbackText, !fallbackText.isEmpty {
            let tokens = tokenizer.tokenize(fallbackText)
            return ParsedChapter(
                title: title,
                index: index,
                text: fallbackText,
                tokens: tokens,
                parseError: false
            )
        }

        // Chapter content extraction failed entirely
        return ParsedChapter(
            title: title,
            index: index,
            text: "This chapter could not be displayed",
            tokens: [],
            parseError: true
        )
    }

    /// Extracts text using Readium's Content API (primary path).
    ///
    /// The Content API is marked experimental but provides the best text extraction.
    /// We wrap it in do/catch for resilience.
    private func extractTextViaContentAPI(
        from publication: Publication,
        link: Link
    ) async -> String? {
        // Create a locator from the link's href
        guard let mediaType = link.mediaType else {
            // Try without media type using href-based content extraction
            let locator = Locator(
                href: link.url(),
                mediaType: .html,
                title: link.title
            )

            guard let content = publication.content(from: locator) else {
                return nil
            }

            return await content.text()
        }

        let locator = Locator(
            href: link.url(),
            mediaType: mediaType,
            title: link.title
        )

        guard let content = publication.content(from: locator) else {
            return nil
        }

        return await content.text()
    }

    /// Fallback text extraction via raw resource access with basic HTML stripping.
    private func extractTextViaRawResource(
        from publication: Publication,
        link: Link
    ) async -> String? {
        guard let resource = publication.get(link) else {
            return nil
        }

        let dataResult = await resource.read()
        switch dataResult {
        case .success(let data):
            guard let htmlString = String(data: data, encoding: .utf8) else {
                return nil
            }
            return stripHTML(htmlString)
        case .failure:
            return nil
        }
    }

    /// Basic HTML tag stripping as a last resort for text extraction.
    ///
    /// Removes HTML tags, collapses whitespace, and decodes common HTML entities.
    private func stripHTML(_ html: String) -> String {
        var text = html

        // Remove script and style blocks entirely
        text = text.replacingOccurrences(
            of: "<(script|style)[^>]*>[\\s\\S]*?</\\1>",
            with: "",
            options: .regularExpression
        )

        // Replace block-level tags with newlines
        text = text.replacingOccurrences(
            of: "</(p|div|h[1-6]|li|tr|br|blockquote)\\s*>",
            with: "\n",
            options: .regularExpression
        )

        // Also handle self-closing <br/> and <br />
        text = text.replacingOccurrences(
            of: "<br\\s*/?>",
            with: "\n",
            options: .regularExpression
        )

        // Remove all remaining HTML tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "\u{2014}"),
            ("&ndash;", "\u{2013}"),
            ("&hellip;", "\u{2026}"),
            ("&lsquo;", "\u{2018}"),
            ("&rsquo;", "\u{2019}"),
            ("&ldquo;", "\u{201C}"),
            ("&rdquo;", "\u{201D}"),
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }

        // Collapse multiple whitespace/newlines
        text = text.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Types

enum EPUBParseError: LocalizedError {
    case invalidURL
    case assetRetrievalFailed(AssetRetrieveURLError)
    case openFailed(PublicationOpenError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The file URL is not valid."
        case .assetRetrievalFailed(let error):
            return "Failed to retrieve EPUB asset: \(error)"
        case .openFailed(let error):
            return "Failed to open EPUB: \(error)"
        }
    }
}
