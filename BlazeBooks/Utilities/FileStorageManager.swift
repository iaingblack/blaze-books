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
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
