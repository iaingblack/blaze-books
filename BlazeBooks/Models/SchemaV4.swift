import Foundation
import SwiftData

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Book.self,
        Chapter.self,
        ReadingPosition.self,
        Shelf.self,
    ]

    @Model
    final class Book {
        var id: UUID = UUID()
        var title: String = ""
        var author: String = ""
        var filePath: String = ""
        var importDate: Date = Date()
        var chapterCount: Int = 0
        var fileHash: String = ""
        var gutenbergId: Int?

        @Attribute(.externalStorage)
        var coverImageData: Data?

        @Attribute(.externalStorage)
        var epubData: Data?

        var isDownloaded: Bool {
            epubData != nil
        }

        @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
        var chapters: [Chapter]? = []

        @Relationship(deleteRule: .cascade, inverse: \ReadingPosition.book)
        var readingPosition: ReadingPosition?

        @Relationship(deleteRule: .nullify, inverse: \Shelf.books)
        var shelves: [Shelf]? = []

        init() {}

        convenience init(
            title: String,
            author: String,
            filePath: String,
            coverImageData: Data? = nil,
            fileHash: String = "",
            gutenbergId: Int? = nil,
            epubData: Data? = nil
        ) {
            self.init()
            self.title = title
            self.author = author
            self.filePath = filePath
            self.coverImageData = coverImageData
            self.fileHash = fileHash
            self.gutenbergId = gutenbergId
            self.epubData = epubData
        }
    }

    @Model
    final class Chapter {
        var id: UUID = UUID()
        var title: String = ""
        var index: Int = 0

        @Attribute(.externalStorage)
        var text: String = ""

        var wordCount: Int = 0
        var book: Book?

        init() {}

        convenience init(
            title: String,
            index: Int,
            text: String = "",
            wordCount: Int = 0
        ) {
            self.init()
            self.title = title
            self.index = index
            self.text = text
            self.wordCount = wordCount
        }
    }

    @Model
    final class ReadingPosition {
        var id: UUID = UUID()
        var chapterIndex: Int = 0
        var wordIndex: Int = 0
        var lastReadDate: Date = Date()
        var verificationSnippet: String = ""
        var book: Book?

        init() {}

        convenience init(
            chapterIndex: Int,
            wordIndex: Int,
            verificationSnippet: String = ""
        ) {
            self.init()
            self.chapterIndex = chapterIndex
            self.wordIndex = wordIndex
            self.verificationSnippet = verificationSnippet
        }
    }

    @Model
    final class Shelf {
        var id: UUID = UUID()
        var name: String = ""
        var createdDate: Date = Date()
        var sortOrder: Int = 0

        @Relationship(deleteRule: .nullify)
        var books: [Book]? = []

        init() {}

        convenience init(name: String) {
            self.init()
            self.name = name
        }
    }
}
