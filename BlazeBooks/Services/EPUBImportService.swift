import CryptoKit
import Foundation
import Observation
import SwiftData
import UIKit

/// Handles the full EPUB import flow: security-scoped URL access, file copy to sandbox,
/// duplicate detection by file hash, Readium parsing, and SwiftData record creation.
///
/// Provides two entry points:
/// - `importEPUB(from:modelContext:)` -- for file-picker imports (handles security-scoped access)
/// - `importLocalEPUB(at:modelContext:gutenbergId:)` -- for local files already in sandbox (used by BookDownloadService)
@MainActor
@Observable
final class EPUBImportService {

    // MARK: - Error Types

    enum ImportError: Error {
        case alreadyInLibrary
        case parseFailed(String)
    }

    // MARK: - Observable State

    var isImporting: Bool = false
    var importError: String?
    var importSuccess: Bool = false

    /// Tracks background extraction progress per book (keyed by fileHash).
    /// ReadingView observes this to show extraction % and wait for chapters.
    var extractionProgress: [String: ExtractionProgress] = [:]

    struct ExtractionProgress {
        var completedChapters: Int = 0
        var totalChapters: Int = 0
        var isComplete: Bool = false
    }

    // MARK: - Dependencies

    private let parserService = EPUBParserService()

    // MARK: - File-Picker Import

    /// Imports an EPUB from a file picker URL into the app's library.
    ///
    /// Flow:
    /// 1. Access the security-scoped resource
    /// 2. Compute file hash for duplicate detection
    /// 3. Copy to app sandbox (Documents/Books/)
    /// 4. Delegate to `importLocalEPUB` for parsing and record creation
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
            // 2. Compute file hash for early duplicate detection
            let fileHash = try FileStorageManager.computeFileHash(at: url)

            // 3. Check for duplicate by file hash before copying
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

            // 5. Import via shared pipeline (pass pre-computed hash to avoid recomputation)
            do {
                try await importLocalEPUB(
                    at: localURL,
                    modelContext: modelContext,
                    fallbackTitle: filenameWithoutExtension(from: url),
                    fileHash: fileHash
                )
                importSuccess = true
            } catch ImportError.alreadyInLibrary {
                importError = "Already in your library"
            } catch {
                // Readium failed: delete the copied file
                try? FileManager.default.removeItem(at: localURL)
                importError = "Couldn't open this book. It may be damaged or DRM-protected."
            }

        } catch {
            importError = "Failed to import: \(error.localizedDescription)"
        }
    }

    // MARK: - Shared Import Pipeline

    /// Imports an EPUB already located in the app sandbox into the library.
    ///
    /// Used by both file-picker imports and BookDownloadService. Handles:
    /// 1. File hash computation and duplicate detection
    /// 2. Readium EPUB parsing
    /// 3. Book, Chapter, and ReadingPosition record creation
    ///
    /// - Parameters:
    ///   - localURL: File URL of the EPUB in the app sandbox
    ///   - modelContext: SwiftData model context for record insertion
    ///   - gutenbergId: Optional Project Gutenberg ID for provenance tracking
    ///   - fallbackTitle: Title to use if EPUB metadata has no title (defaults to filename)
    /// - Throws: `ImportError.alreadyInLibrary` if duplicate detected, or parsing errors
    func importLocalEPUB(
        at localURL: URL,
        modelContext: ModelContext,
        gutenbergId: Int? = nil,
        fallbackTitle: String? = nil,
        fileHash: String? = nil
    ) async throws {
        // 1. Read file and compute hash off main thread in a single pass
        let (epubFileData, computedHash) = try await Self.readFileAndHash(at: localURL, precomputedHash: fileHash)

        // 2. Check for duplicate by file hash
        let fetchDescriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> { book in
                book.fileHash == computedHash
            }
        )
        let existingBooks = try modelContext.fetch(fetchDescriptor)
        if !existingBooks.isEmpty {
            throw ImportError.alreadyInLibrary
        }

        // 3. Fast metadata-only parse (no chapter content extraction)
        let metadata: EPUBParserService.ParsedBookMetadata
        do {
            metadata = try await parserService.parseEPUBMetadata(at: localURL)
        } catch {
            throw ImportError.parseFailed(error.localizedDescription)
        }

        // 4. Determine metadata with smart fallbacks
        let title = metadata.title.isEmpty
            ? (fallbackTitle ?? filenameWithoutExtension(from: localURL))
            : metadata.title
        let author = metadata.author.isEmpty
            ? "Unknown Author"
            : metadata.author

        let coverData = metadata.coverData

        // Compute relative path from Documents/Books/
        let relativePath = localURL.lastPathComponent

        // 5. Create Book record
        let book = Book(
            title: title,
            author: author,
            filePath: relativePath,
            coverImageData: coverData,
            fileHash: computedHash,
            gutenbergId: gutenbergId,
            epubData: epubFileData
        )
        book.chapterCount = metadata.chapterStubs.count

        // 6. Create Chapter records with empty text (deferred extraction)
        var chapters: [Chapter] = []
        for stub in metadata.chapterStubs {
            let chapter = Chapter(
                title: stub.title,
                index: stub.index
            )
            chapter.book = book
            chapters.append(chapter)
        }
        book.chapters = chapters

        // 7. Create ReadingPosition initialized to chapter 0, word 0
        let readingPosition = ReadingPosition(
            chapterIndex: 0,
            wordIndex: 0,
            verificationSnippet: ""
        )
        readingPosition.book = book
        book.readingPosition = readingPosition

        // 8. Insert all records into ModelContext (SwiftData auto-saves)
        modelContext.insert(book)

        // 9. Fire background chapter extraction
        // Key by fileHash (stable before save) instead of persistentModelID (temporary before save)
        let progressKey = computedHash
        let fileURL = localURL
        let totalChapterCount = metadata.chapterStubs.count
        extractionProgress[progressKey] = ExtractionProgress(
            completedChapters: 0,
            totalChapters: totalChapterCount
        )
        Task { [parserService, weak self] in
            await Self.extractChaptersInBackground(
                chapters: chapters,
                fileURL: fileURL,
                parserService: parserService,
                onProgress: { completed in
                    self?.extractionProgress[progressKey]?.completedChapters = completed
                },
                onComplete: {
                    self?.extractionProgress[progressKey]?.isComplete = true
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                        self?.extractionProgress.removeValue(forKey: progressKey)
                    }
                }
            )
        }
    }

    // MARK: - Background Chapter Extraction

    /// Extracts chapter text in the background after fast import.
    /// Re-opens the EPUB, extracts each chapter sequentially, and updates the Chapter objects directly.
    /// Reports progress via callbacks so ReadingView can show extraction %.
    private static func extractChaptersInBackground(
        chapters: [Chapter],
        fileURL: URL,
        parserService: EPUBParserService,
        onProgress: @MainActor @Sendable (Int) -> Void,
        onComplete: @MainActor @Sendable () -> Void
    ) async {
        do {
            let publication = try await parserService.openEPUB(at: fileURL)
            let spineCount = publication.readingOrder.count
            let tocMap = await parserService.tocTitleMap(from: publication)

            let sortedChapters = chapters.sorted { $0.index < $1.index }

            for spineIndex in 0..<spineCount {
                guard spineIndex < sortedChapters.count else { continue }
                let chapter = sortedChapters[spineIndex]

                // Skip already-extracted chapters
                guard chapter.text.isEmpty else {
                    await onProgress(spineIndex + 1)
                    continue
                }

                let parsed = await parserService.extractSingleChapter(
                    from: publication,
                    at: spineIndex,
                    tocTitleMap: tocMap
                )

                chapter.text = parsed.text
                chapter.wordCount = parsed.wordCount

                await onProgress(spineIndex + 1)
            }

            await onComplete()
        } catch {
            await onComplete()
            #if DEBUG
            print("[EPUBImportService] Background extraction failed: \(error)")
            #endif
        }
    }

    // MARK: - Private Helpers

    /// Maximum EPUB file size (100 MB). Files larger than this are rejected to prevent
    /// memory exhaustion when loading into Data.
    private static let maxFileSize: UInt64 = 100 * 1024 * 1024

    /// Reads the file data and computes its SHA256 hash off the main thread in a single pass.
    /// If a pre-computed hash is provided, reads the file once and returns that hash.
    /// Rejects files larger than 100 MB.
    private nonisolated static func readFileAndHash(
        at url: URL,
        precomputedHash: String?
    ) async throws -> (Data, String) {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0
        if fileSize > maxFileSize {
            throw ImportError.parseFailed("File exceeds 100 MB size limit")
        }
        let data = try Data(contentsOf: url)
        if let hash = precomputedHash {
            return (data, hash)
        }
        let digest = SHA256.hash(data: data)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return (data, hash)
    }

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
