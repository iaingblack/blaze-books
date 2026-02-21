import Foundation
import Observation
import os
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

    /// Extracts chapters from the publication using readingOrder for reliable text extraction
    /// and table of contents for chapter titles.
    ///
    /// TOC links often contain fragment identifiers (e.g., `chapter.xhtml#section2`) which
    /// cause both `publication.content(from:)` and `publication.get(link)` to fail silently.
    /// Using readingOrder spine links (which have clean hrefs) avoids this entirely.
    private func extractChapters(from publication: Publication) async -> [ParsedChapter] {
        // Build title map from TOC (for display names)
        let tocTitleMap = await buildTOCTitleMap(from: publication)

        // Use readingOrder as the primary source — these have clean hrefs, no fragments
        let spineLinks = publication.readingOrder
        guard !spineLinks.isEmpty else { return [] }

        let totalChapters = spineLinks.count
        let completedCount = OSAllocatedUnfairLock(initialState: 0)

        let chapters = await withTaskGroup(of: ParsedChapter.self, returning: [ParsedChapter].self) { group in
            for (index, spineLink) in spineLinks.enumerated() {
                let href = spineLink.url().string
                let chapterTitle = tocTitleMap[href]
                    ?? spineLink.title
                    ?? "Chapter \(index + 1)"

                group.addTask {
                    let chapter = await self.extractChapter(
                        from: publication,
                        spineLink: spineLink,
                        title: chapterTitle,
                        index: index
                    )
                    let completed = completedCount.withLock { count -> Int in
                        count += 1
                        return count
                    }
                    await MainActor.run {
                        self.parseProgress = Double(completed) / Double(totalChapters)
                    }
                    return chapter
                }
            }

            var results: [ParsedChapter] = []
            results.reserveCapacity(totalChapters)
            for await chapter in group {
                results.append(chapter)
            }
            return results
        }

        return chapters.sorted { $0.index < $1.index }
    }

    /// Builds a map from spine href → chapter title using the table of contents.
    /// Strips fragment identifiers from TOC hrefs to match against readingOrder hrefs.
    private func buildTOCTitleMap(from publication: Publication) async -> [String: String] {
        var titleMap: [String: String] = [:]

        let tocResult = await publication.tableOfContents()
        let tocLinks: [Link]
        switch tocResult {
        case .success(let links):
            tocLinks = links
        case .failure:
            return titleMap
        }

        for link in tocLinks {
            guard let title = link.title, !title.isEmpty else { continue }
            // Strip fragment from href to match spine links
            let href = link.url().string
            let baseHref = href.components(separatedBy: "#").first ?? href
            // First TOC entry per spine file wins (most specific title)
            if titleMap[baseHref] == nil {
                titleMap[baseHref] = title
            }
        }

        return titleMap
    }

    /// Extracts a single chapter's text from a spine link and tokenizes it.
    private func extractChapter(
        from publication: Publication,
        spineLink: Link,
        title: String,
        index: Int
    ) async -> ParsedChapter {
        // Primary: load raw resource directly from spine (most reliable)
        let text = await extractTextFromResource(from: publication, link: spineLink)

        if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokens = tokenizer.tokenize(cleanText)
            return ParsedChapter(
                title: title,
                index: index,
                text: cleanText,
                tokens: tokens,
                parseError: false
            )
        }

        // Fallback: try Content API
        let contentText = await extractTextViaContentAPI(from: publication, link: spineLink)

        if let contentText = contentText, !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanText = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokens = tokenizer.tokenize(cleanText)
            return ParsedChapter(
                title: title,
                index: index,
                text: cleanText,
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

    /// Primary text extraction: load raw HTML from spine resource and strip tags.
    /// Uses readingOrder links which have clean hrefs (no fragments).
    private func extractTextFromResource(
        from publication: Publication,
        link: Link
    ) async -> String? {
        guard let resource = publication.get(link) else {
            return nil
        }

        let dataResult = await resource.read()
        switch dataResult {
        case .success(let data):
            // Try UTF-8 first, then Latin-1 as fallback
            let htmlString: String?
            if let utf8 = String(data: data, encoding: .utf8) {
                htmlString = utf8
            } else {
                htmlString = String(data: data, encoding: .isoLatin1)
            }
            guard let html = htmlString else { return nil }
            return stripHTML(html)
        case .failure:
            return nil
        }
    }

    /// Fallback text extraction using Readium's Content API.
    private func extractTextViaContentAPI(
        from publication: Publication,
        link: Link
    ) async -> String? {
        let mediaType = link.mediaType ?? .html
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

    /// Single-pass HTML tag stripping optimized for EPUB chapter text extraction.
    ///
    /// Walks the string once, tracking whether we're inside a tag or an ignored block
    /// (head, script, style, h1-h6). Decodes HTML entities inline and normalizes whitespace.
    private func stripHTML(_ html: String) -> String {
        // Entity lookup table
        let entityMap: [String: Character] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"",
            "apos": "'", "nbsp": " ",
            "mdash": "\u{2014}", "ndash": "\u{2013}", "hellip": "\u{2026}",
            "lsquo": "\u{2018}", "rsquo": "\u{2019}",
            "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        ]

        // Ignored block tags whose content we skip entirely
        let ignoredTags: Set<String> = ["head", "script", "style", "h1", "h2", "h3", "h4", "h5", "h6"]
        // Block-level closing tags that produce a newline
        let blockTags: Set<String> = ["p", "div", "li", "tr", "br", "blockquote"]

        var output = ""
        output.reserveCapacity(html.count / 3)

        var insideTag = false
        var tagBuffer = ""
        var ignoredBlock: String? = nil  // the tag name we're currently ignoring
        var lastWasSpace = false
        var newlineCount = 0

        for ch in html {
            if insideTag {
                if ch == ">" {
                    insideTag = false
                    let tag = tagBuffer.lowercased()
                    tagBuffer = ""

                    // Check for opening ignored blocks: <head>, <script ...>, etc.
                    if ignoredBlock == nil {
                        let tagName = extractTagName(from: tag)
                        if ignoredTags.contains(tagName) && !tag.hasPrefix("/") {
                            ignoredBlock = tagName
                            continue
                        }
                    }

                    // Check for closing ignored blocks: </head>, </script>, etc.
                    if let blocked = ignoredBlock {
                        if tag.hasPrefix("/") {
                            let closeName = extractTagName(from: String(tag.dropFirst()))
                            if closeName == blocked {
                                ignoredBlock = nil
                                // Heading closings produce a newline
                                if closeName.count == 2 && closeName.hasPrefix("h") {
                                    if newlineCount < 2 {
                                        output.append("\n")
                                        newlineCount += 1
                                        lastWasSpace = true
                                    }
                                }
                            }
                        }
                        continue
                    }

                    // Block-level closing tags → newline
                    if tag.hasPrefix("/") {
                        let closeName = extractTagName(from: String(tag.dropFirst()))
                        if blockTags.contains(closeName) && newlineCount < 2 {
                            output.append("\n")
                            newlineCount += 1
                            lastWasSpace = true
                        }
                    }
                    // Self-closing <br/> or <br />
                    else if tag.hasPrefix("br") && newlineCount < 2 {
                        output.append("\n")
                        newlineCount += 1
                        lastWasSpace = true
                    }
                } else {
                    tagBuffer.append(ch)
                }
                continue
            }

            // Inside ignored block — skip all content
            if ignoredBlock != nil {
                if ch == "<" {
                    insideTag = true
                    tagBuffer = ""
                }
                continue
            }

            if ch == "<" {
                insideTag = true
                tagBuffer = ""
                continue
            }

            // Normal character — append with whitespace normalization
            // (HTML entities like &amp; pass through here and are decoded in a post-pass
            // on the much smaller stripped text)
            if ch == "\n" || ch == "\r" {
                if newlineCount < 2 {
                    output.append("\n")
                    newlineCount += 1
                    lastWasSpace = true
                }
            } else if ch == " " || ch == "\t" {
                if !lastWasSpace {
                    output.append(" ")
                    lastWasSpace = true
                }
            } else {
                output.append(ch)
                lastWasSpace = false
                newlineCount = 0
            }
        }

        // Decode HTML entities in the stripped text (cheap on clean text)
        var result = output
        for (name, replacement) in entityMap {
            result = result.replacingOccurrences(of: "&\(name);", with: String(replacement))
        }
        // Handle numeric entities (&#39;, &#160;, etc.)
        if result.contains("&#") {
            var decoded = ""
            decoded.reserveCapacity(result.count)
            var i = result.startIndex
            while i < result.endIndex {
                if result[i] == "&",
                   result.index(after: i) < result.endIndex,
                   result[result.index(after: i)] == "#" {
                    var j = result.index(i, offsetBy: 2)
                    var numStr = ""
                    while j < result.endIndex && result[j] != ";" && numStr.count < 7 {
                        numStr.append(result[j])
                        j = result.index(after: j)
                    }
                    if j < result.endIndex && result[j] == ";",
                       let code = UInt32(numStr),
                       let scalar = Unicode.Scalar(code) {
                        decoded.append(Character(scalar))
                        i = result.index(after: j)
                        continue
                    }
                }
                decoded.append(result[i])
                i = result.index(after: i)
            }
            result = decoded
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts the tag name from a tag string like "div class='x'" → "div".
    private func extractTagName(from tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        if let spaceIdx = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" || $0 == "/" || $0 == "\n" }) {
            return String(trimmed[trimmed.startIndex..<spaceIdx])
        }
        // Strip trailing / for self-closing tags
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
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
