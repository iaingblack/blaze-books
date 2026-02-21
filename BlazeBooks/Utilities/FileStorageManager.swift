import CryptoKit
import Foundation

struct FileStorageManager {

    static var booksDirectory: URL {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let booksURL = documentsURL.appendingPathComponent("Books", isDirectory: true)

        if !FileManager.default.fileExists(atPath: booksURL.path) {
            try? FileManager.default.createDirectory(
                at: booksURL,
                withIntermediateDirectories: true
            )
        }

        return booksURL
    }

    static func localURL(for fileName: String) -> URL {
        booksDirectory.appendingPathComponent(fileName)
    }

    static func fileExists(_ fileName: String) -> Bool {
        let url = localURL(for: fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func deleteFile(_ fileName: String) throws {
        let url = localURL(for: fileName)
        try FileManager.default.removeItem(at: url)
    }

    static func computeFileHash(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 65_536)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Creates a temporary file from EPUB data for Readium parsing.
    /// Returns the temporary file URL. Caller is responsible for cleanup.
    static func temporaryFileURL(from data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(filename.isEmpty ? "temp.epub" : filename)
        try data.write(to: tempURL)
        return tempURL
    }
}
