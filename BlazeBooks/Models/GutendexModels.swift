import Foundation

struct GutendexResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [GutendexBook]
}

struct GutendexBook: Codable, Identifiable {
    let id: Int
    let title: String
    let authors: [GutendexPerson]
    let subjects: [String]
    let bookshelves: [String]
    let languages: [String]
    let copyright: Bool?
    let mediaType: String
    let formats: [String: String]
    let downloadCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, authors, subjects, bookshelves, languages
        case copyright, formats
        case mediaType = "media_type"
        case downloadCount = "download_count"
    }

    /// EPUB download URL from formats dictionary
    var epubURL: URL? {
        guard let urlString = formats["application/epub+zip"] else { return nil }
        return URL(string: urlString)
    }

    /// Cover image URL from formats dictionary
    var coverImageURL: URL? {
        guard let urlString = formats["image/jpeg"] else { return nil }
        return URL(string: urlString)
    }

    /// Primary author name (formatted as "First Last" from Gutenberg's "Last, First")
    var primaryAuthor: String {
        guard let author = authors.first else { return "Unknown Author" }
        let parts = author.name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            return "\(parts[1]) \(parts[0])"
        }
        return author.name
    }
}

struct GutendexPerson: Codable {
    let name: String
    let birthYear: Int?
    let deathYear: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case birthYear = "birth_year"
        case deathYear = "death_year"
    }
}

struct Genre: Identifiable {
    let id: UUID
    let name: String
    let topic: String
    let systemImage: String

    init(name: String, topic: String, systemImage: String) {
        self.id = UUID()
        self.name = name
        self.topic = topic
        self.systemImage = systemImage
    }

    static let all: [Genre] = [
        Genre(name: "Fiction", topic: "fiction", systemImage: "book"),
        Genre(name: "Science Fiction", topic: "science fiction", systemImage: "sparkles"),
        Genre(name: "Mystery", topic: "mystery", systemImage: "magnifyingglass"),
        Genre(name: "Adventure", topic: "adventure", systemImage: "figure.hiking"),
        Genre(name: "Romance", topic: "romance", systemImage: "heart"),
        Genre(name: "Horror", topic: "horror", systemImage: "moon.stars"),
        Genre(name: "Philosophy", topic: "philosophy", systemImage: "brain.head.profile"),
        Genre(name: "Poetry", topic: "poetry", systemImage: "text.quote"),
        Genre(name: "History", topic: "history", systemImage: "clock.arrow.circlepath"),
        Genre(name: "Biography", topic: "biography", systemImage: "person"),
        Genre(name: "Science", topic: "science", systemImage: "atom"),
        Genre(name: "Children's", topic: "children", systemImage: "face.smiling"),
        Genre(name: "Short Stories", topic: "short stories", systemImage: "text.alignleft"),
        Genre(name: "Drama", topic: "drama", systemImage: "theatermasks"),
    ]
}
