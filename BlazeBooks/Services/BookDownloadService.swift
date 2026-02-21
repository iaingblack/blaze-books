import Foundation
import Observation
import SwiftData

/// Orchestrates downloading free EPUB books from Project Gutenberg and importing them
/// into the user's library via the shared EPUBImportService pipeline.
///
/// Tracks per-book download state by Gutenberg ID so the UI can show progress indicators,
/// completion badges, and retry options for each book independently.
@MainActor
@Observable
final class BookDownloadService {

    // MARK: - Types

    enum DownloadState: Equatable {
        case downloading
        case importing
        case completed
        case failed(String)
    }

    // MARK: - Observable State

    /// Active download states keyed by Gutenberg book ID.
    var activeDownloads: [Int: DownloadState] = [:]

    // MARK: - Dependencies

    private let importService: EPUBImportService

    // MARK: - Init

    init(importService: EPUBImportService) {
        self.importService = importService
    }

    // MARK: - Public API

    /// Downloads a Gutenberg EPUB and imports it into the library.
    ///
    /// Flow:
    /// 1. Extract EPUB URL from the book's formats dictionary
    /// 2. Download via URLSession to a temporary file
    /// 3. Move temp file to sandbox immediately (per research Pitfall 4)
    /// 4. Import via EPUBImportService.importLocalEPUB pipeline
    /// 5. Update state to .completed or .failed
    ///
    /// If the book is already in the library (duplicate detection via file hash),
    /// the state transitions to .completed (not an error).
    func downloadBook(_ gutendexBook: GutendexBook, modelContext: ModelContext) async {
        guard let epubURL = gutendexBook.epubURL else {
            activeDownloads[gutendexBook.id] = .failed("No EPUB available")
            return
        }

        activeDownloads[gutendexBook.id] = .downloading

        do {
            // 1. Download EPUB to temporary location
            let (tempURL, _) = try await URLSession.shared.download(from: epubURL)

            // 2. Move to app sandbox immediately (temp file lifetime is short)
            let fileName = "gutenberg-\(gutendexBook.id).epub"
            let destinationURL = FileStorageManager.booksDirectory
                .appendingPathComponent(fileName)

            // Remove existing file at destination if re-downloading
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // 3. Import via existing pipeline
            activeDownloads[gutendexBook.id] = .importing

            try await importService.importLocalEPUB(
                at: destinationURL,
                modelContext: modelContext,
                gutenbergId: gutendexBook.id
            )

            activeDownloads[gutendexBook.id] = .completed

        } catch EPUBImportService.ImportError.alreadyInLibrary {
            // Book already in library -- treat as success, not error
            activeDownloads[gutendexBook.id] = .completed

        } catch {
            // Clean up the downloaded file on failure
            let fileName = "gutenberg-\(gutendexBook.id).epub"
            let destinationURL = FileStorageManager.booksDirectory
                .appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destinationURL)

            activeDownloads[gutendexBook.id] = .failed("Download failed. Tap to retry.")
        }
    }
}
