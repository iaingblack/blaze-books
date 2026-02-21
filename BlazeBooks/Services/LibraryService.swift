import Foundation
import SwiftData

/// Stateless service providing library management operations.
///
/// All methods are static (like `WordTokenizer` pattern). Handles book deletion
/// with file cleanup, shelf CRUD, and book-shelf relationship management.
struct LibraryService {

    // MARK: - Book Deletion

    /// Deletes a book from SwiftData and removes its EPUB file from disk.
    ///
    /// Order of operations (per research Pitfall 3):
    /// 1. Capture file path before deletion
    /// 2. Delete SwiftData record (cascade rules handle chapters and reading position;
    ///    `.nullify` on shelves removes book from shelf.books arrays)
    /// 3. Delete EPUB file -- log warning on failure (orphaned file < orphaned record)
    static func deleteBook(_ book: Book, modelContext: ModelContext) {
        let filePath = book.filePath

        // SwiftData cascade: chapters + reading position deleted automatically
        // SwiftData nullify: book removed from all shelf.books arrays automatically
        modelContext.delete(book)

        // Clean up EPUB file from disk
        do {
            try FileStorageManager.deleteFile(filePath)
        } catch {
            print("[LibraryService] Warning: Could not delete file '\(filePath)': \(error)")
        }
    }

    // MARK: - Shelf CRUD

    /// Creates a new shelf with the given name and inserts it into the model context.
    ///
    /// Per research Pitfall 2: insert before relating -- the shelf is inserted
    /// into the context before it is returned so callers can safely assign books.
    @discardableResult
    static func createShelf(name: String, modelContext: ModelContext) -> Shelf {
        let shelf = Shelf(name: name)
        modelContext.insert(shelf)
        return shelf
    }

    /// Deletes a shelf from SwiftData.
    ///
    /// The `.nullify` delete rule ensures books are NOT deleted -- they are simply
    /// removed from this shelf's relationship.
    static func deleteShelf(_ shelf: Shelf, modelContext: ModelContext) {
        modelContext.delete(shelf)
    }

    /// Renames a shelf.
    static func renameShelf(_ shelf: Shelf, to newName: String) {
        shelf.name = newName
    }

    // MARK: - Book-Shelf Relationship

    /// Adds a book to a shelf if not already present.
    ///
    /// Guards against duplicates by checking book ID in the shelf's books array.
    static func addBookToShelf(_ book: Book, _ shelf: Shelf) {
        guard !(shelf.books?.contains(where: { $0.id == book.id }) ?? false) else { return }
        shelf.books?.append(book)
    }

    /// Removes a book from a shelf.
    static func removeBookFromShelf(_ book: Book, _ shelf: Shelf) {
        shelf.books?.removeAll(where: { $0.id == book.id })
    }
}
