import Foundation
import Observation
import SwiftData
import UIKit

/// Handles the full EPUB import flow: security-scoped URL access, file copy to sandbox,
/// duplicate detection by file hash, Readium parsing, and SwiftData record creation.
@MainActor
@Observable
final class EPUBImportService {

    // MARK: - Observable State

    var isImporting: Bool = false
    var importError: String?
    var importSuccess: Bool = false

    // MARK: - Dependencies

    private let parserService = EPUBParserService()

    // MARK: - Import

    /// Imports an EPUB from a file picker URL into the app's library.
    ///
    /// Flow:
    /// 1. Access the security-scoped resource
    /// 2. Compute file hash for duplicate detection
    /// 3. Copy to app sandbox (Documents/Books/)
    /// 4. Parse with Readium to extract metadata and chapters
    /// 5. Persist Book, Chapter, and ReadingPosition records in SwiftData
    func importEPUB(from url: URL, modelContext: ModelContext) async {
        isImporting = true
        importError = nil
        importSuccess = false
        defer { isImporting = false }

        // 1. Access security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Cannot access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // 2. Compute file hash for duplicate detection
            let fileHash = try FileStorageManager.computeFileHash(at: url)

            // 3. Check for duplicate by file hash
            let fetchDescriptor = FetchDescriptor<Book>(
                predicate: #Predicate<Book> { book in
                    book.fileHash == fileHash
                }
            )
            let existingBooks = try modelContext.fetch(fetchDescriptor)
            if !existingBooks.isEmpty {
                importError = "Already in your library"
                return
            }

            // 4. Copy file to sandbox
            let localURL = try copyToSandbox(from: url)

            // 5. Parse EPUB with Readium
            let parsedBook: EPUBParserService.ParsedBook
            do {
                parsedBook = try await parserService.parseEPUB(at: localURL)
            } catch {
                // Readium failed completely: delete the copied file, set error, do NOT add to library
                try? FileManager.default.removeItem(at: localURL)
                importError = "Couldn't open this book. It may be damaged or DRM-protected."
                return
            }

            // 6. Determine metadata with smart fallbacks
            let title = parsedBook.title.isEmpty
                ? filenameWithoutExtension(from: url)
                : parsedBook.title
            let author = parsedBook.author.isEmpty
                ? "Unknown Author"
                : parsedBook.author

            // Convert cover UIImage to JPEG data
            let coverData = parsedBook.coverData

            // Compute relative path from Documents/Books/
            let fileName = localURL.lastPathComponent
            let relativePath = fileName

            // 7. Create Book record
            let book = Book(
                title: title,
                author: author,
                filePath: relativePath,
                coverImageData: coverData,
                fileHash: fileHash
            )
            book.chapterCount = parsedBook.chapters.count

            // 8. Create Chapter records
            var chapters: [Chapter] = []
            for parsedChapter in parsedBook.chapters {
                let chapter = Chapter(
                    title: parsedChapter.title,
                    index: parsedChapter.index,
                    text: parsedChapter.text,
                    wordCount: parsedChapter.parseError ? 0 : parsedChapter.tokens.count
                )
                chapter.book = book
                chapters.append(chapter)
            }
            book.chapters = chapters

            // 9. Create ReadingPosition initialized to chapter 0, word 0
            let readingPosition = ReadingPosition(
                chapterIndex: 0,
                wordIndex: 0,
                verificationSnippet: ""
            )
            readingPosition.book = book
            book.readingPosition = readingPosition

            // 10. Insert all records into ModelContext
            modelContext.insert(book)

            importSuccess = true

        } catch {
            importError = "Failed to import: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Helpers

    /// Copies the EPUB file to Documents/Books/, handling filename collisions.
    private func copyToSandbox(from sourceURL: URL) throws -> URL {
        let booksDir = FileStorageManager.booksDirectory
        let originalFileName = sourceURL.lastPathComponent

        var destinationURL = booksDir.appendingPathComponent(originalFileName)

        // If a file with the same name exists (different book, different hash),
        // append a UUID suffix to avoid overwriting
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let nameWithoutExt = (originalFileName as NSString).deletingPathExtension
            let ext = (originalFileName as NSString).pathExtension
            let uniqueName = "\(nameWithoutExt)-\(UUID().uuidString).\(ext)"
            destinationURL = booksDir.appendingPathComponent(uniqueName)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    /// Extracts a human-readable name from a filename by removing the .epub extension.
    private func filenameWithoutExtension(from url: URL) -> String {
        let filename = url.lastPathComponent
        if filename.lowercased().hasSuffix(".epub") {
            return String(filename.dropLast(5))
        }
        return filename
    }
}
