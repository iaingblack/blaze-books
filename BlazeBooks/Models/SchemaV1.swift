import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Book.self,
        Chapter.self,
        ReadingPosition.self,
    ]

    @Model
    final class Book {
        var id: UUID = UUID()
        var title: String = ""
        var author: String = ""
        var filePath: String = ""
        var coverImageData: Data?
        var importDate: Date = Date()
        var chapterCount: Int = 0
        var fileHash: String = ""

        @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
        var chapters: [Chapter]? = []

        @Relationship(deleteRule: .cascade, inverse: \ReadingPosition.book)
        var readingPosition: ReadingPosition?

        init() {}

        convenience init(
            title: String,
            author: String,
            filePath: String,
            coverImageData: Data? = nil,
            fileHash: String = ""
        ) {
            self.init()
            self.title = title
            self.author = author
            self.filePath = filePath
            self.coverImageData = coverImageData
            self.fileHash = fileHash
        }
    }

    @Model
    final class Chapter {
        var id: UUID = UUID()
        var title: String = ""
        var index: Int = 0
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
}

enum BlazeBooksMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []
}
