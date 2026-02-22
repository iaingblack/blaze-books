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

    /// Creates a GutendexBook from OPDS search data using known PG URL patterns.
    init(id: Int, title: String, authorName: String) {
        self.id = id
        self.title = title
        self.authors = [GutendexPerson(name: authorName, birthYear: nil, deathYear: nil)]
        self.subjects = []
        self.bookshelves = []
        self.languages = ["en"]
        self.copyright = false
        self.mediaType = "Text"
        self.downloadCount = 0
        self.formats = [
            "application/epub+zip": "https://www.gutenberg.org/ebooks/\(id).epub3.images",
            "image/jpeg": "https://www.gutenberg.org/cache/epub/\(id)/pg\(id).cover.medium.jpg"
        ]
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

struct Genre: Identifiable, Hashable {
    let id: UUID
    let name: String
    let topic: String
    let systemImage: String
    let bookIds: [Int]

    init(name: String, topic: String, systemImage: String, bookIds: [Int]) {
        self.id = UUID()
        self.name = name
        self.topic = topic
        self.systemImage = systemImage
        self.bookIds = bookIds
    }

    // Hash by topic (unique, stable) rather than UUID (generated fresh each init)
    func hash(into hasher: inout Hasher) {
        hasher.combine(topic)
    }

    static func == (lhs: Genre, rhs: Genre) -> Bool {
        lhs.topic == rhs.topic
    }

    // Curated popular Gutenberg book IDs per genre.
    // Using IDs instead of the topic search parameter because the Gutendex API's
    // topic query does a full-text scan taking 30-90+ seconds (unusable in a mobile app).
    // The ids parameter returns results in ~4 seconds.
    static let all: [Genre] = [
        Genre(name: "Fiction", topic: "fiction", systemImage: "book", bookIds: [
            1342,  // Pride and Prejudice
            84,    // Frankenstein
            1400,  // Great Expectations
            98,    // A Tale of Two Cities
            145,   // Middlemarch
            1260,  // Jane Eyre
            768,   // Wuthering Heights
            174,   // The Picture of Dorian Gray
            64317, // The Great Gatsby
            2600,  // War and Peace
            1399,  // Anna Karenina
            5200,  // Metamorphosis
            730,   // Oliver Twist
            158,   // Emma
            161,   // Sense and Sensibility
            135,   // Les Miserables
            996,   // Don Quixote
            110,   // Tess of the d'Urbervilles
            1023,  // Bleak House
            219,   // Heart of Darkness
            7178,  // Swann's Way
            4217,  // A Portrait of the Artist as a Young Man
            2814,  // Dubliners
            829,   // Gulliver's Travels
            19942, // Candide
        ]),
        Genre(name: "Science Fiction", topic: "science fiction", systemImage: "sparkles", bookIds: [
            35,    // The Time Machine
            36,    // The War of the Worlds
            164,   // Twenty Thousand Leagues Under the Sea
            84,    // Frankenstein
            8492,  // The King in Yellow
            21279, // Flatland
            62,    // A Princess of Mars
            155,   // The Moonstone
            1952,  // The Yellow Wallpaper
            60230, // Journey to the Center of the Earth
            23042, // The Island of Doctor Moreau
            5230,  // The Invisible Man
            1743,  // The Food of the Gods
            159,   // The First Men in the Moon
            3527,  // In the Year 2889
            19141, // The Sleeper Awakes
            6927,  // The Coming Race
            624,   // Looking Backward
        ]),
        Genre(name: "Mystery", topic: "mystery", systemImage: "magnifyingglass", bookIds: [
            1661,  // Adventures of Sherlock Holmes
            2852,  // Hound of the Baskervilles
            244,   // A Study in Scarlet
            2554,  // Crime and Punishment
            69087, // The Murder of Roger Ackroyd
            43,    // Dr. Jekyll and Mr. Hyde
            863,   // The Moonstone
            108,   // The Sign of the Four
            3289,  // The Valley of Fear
            834,   // The Return of Sherlock Holmes
            903,   // His Last Bow
            2097,  // The Secret Adversary
            1155,  // The Mysterious Affair at Styles
            58866, // The 39 Steps
            10007, // Carmilla
            2148,  // Works of Edgar Allan Poe
            7735,  // Paul Clifford
        ]),
        Genre(name: "Adventure", topic: "adventure", systemImage: "figure.hiking", bookIds: [
            2701,  // Moby Dick
            120,   // Treasure Island
            1184,  // The Count of Monte Cristo
            1259,  // Twenty Years After
            74,    // Tom Sawyer
            76,    // Huckleberry Finn
            521,   // Robinson Crusoe
            55,    // Wizard of Oz
            16,    // Peter Pan
            236,   // The Jungle Book
            164,   // Twenty Thousand Leagues
            35,    // The Time Machine
            829,   // Gulliver's Travels
            996,   // Don Quixote
            132,   // The Art of War
            3176,  // The Call of the Wild
            215,   // The Call of the Wild (alt)
            910,   // White Fang
            2166,  // King Solomon's Mines
            27681, // The Three Musketeers
        ]),
        Genre(name: "Romance", topic: "romance", systemImage: "heart", bookIds: [
            1342,  // Pride and Prejudice
            1260,  // Jane Eyre
            161,   // Sense and Sensibility
            158,   // Emma
            1399,  // Anna Karenina
            2641,  // A Room with a View
            67979, // The Blue Castle
            768,   // Wuthering Heights
            105,   // Persuasion
            121,   // Northanger Abbey
            394,   // Cranford
            16389, // The Enchanted April
            514,   // Little Women
            37106, // Little Women (alt)
            174,   // The Picture of Dorian Gray
            110,   // Tess of the d'Urbervilles
            4276,  // Far from the Madding Crowd
        ]),
        Genre(name: "Horror", topic: "horror", systemImage: "moon.stars", bookIds: [
            345,   // Dracula
            84,    // Frankenstein
            43,    // Dr. Jekyll and Mr. Hyde
            8492,  // The King in Yellow
            10007, // Carmilla
            2148,  // Works of Edgar Allan Poe
            209,   // The Turn of the Screw
            41,    // The Legend of Sleepy Hollow
            46,    // A Christmas Carol
            932,   // The Fall of the House of Usher
            1064,  // The Masque of the Red Death
            14975, // The Willows
            326,   // The Phantom of the Opera
            42324, // Frankenstein (alt)
            14168, // The Wendigo
            696,   // The Castle of Otranto
        ]),
        Genre(name: "Philosophy", topic: "philosophy", systemImage: "brain.head.profile", bookIds: [
            1998,  // Thus Spake Zarathustra
            3207,  // Leviathan
            1497,  // The Republic
            4363,  // Beyond Good and Evil
            45109, // The Enchiridion
            2680,  // Meditations
            4280,  // Critique of Pure Reason
            5740,  // Tractatus Logico-Philosophicus
            8438,  // Ethics of Aristotle
            1600,  // Symposium
            34901, // On Liberty
            7370,  // Second Treatise of Government
            52319, // Genealogy of Morals
            3296,  // Confessions of St. Augustine
            205,   // Walden
        ]),
        Genre(name: "Poetry", topic: "poetry", systemImage: "text.quote", bookIds: [
            6130,  // The Iliad
            1727,  // The Odyssey
            8800,  // The Divine Comedy
            26,    // Paradise Lost
            16328, // Beowulf
            1524,  // Hamlet
            1513,  // Romeo and Juliet
            100,   // Complete Works of Shakespeare
            21700, // Don Juan
            1321,  // Leaves of Grass
            1065,  // The Raven
            4925,  // Sonnets (Shakespeare)
            21765, // Metamorphoses (Ovid)
            12,    // Through the Looking-Glass
        ]),
        Genre(name: "History", topic: "history", systemImage: "clock.arrow.circlepath", bookIds: [
            26184, // Simple Sabotage Field Manual
            132,   // The Art of War
            7142,  // History of the Peloponnesian War
            147,   // Common Sense
            3300,  // Wealth of Nations
            815,   // Democracy in America
            2848,  // Antiquities of the Jews
            1946,  // On War
            10636, // Travels of Marco Polo
            1232,  // The Prince
            2680,  // Meditations
            1228,  // On the Origin of Species
            408,   // The Souls of Black Folk
            852,   // The Decline and Fall of the Roman Empire
        ]),
        Genre(name: "Biography", topic: "biography", systemImage: "person", bookIds: [
            23,    // Narrative of Frederick Douglass
            20203, // Autobiography of Benjamin Franklin
            245,   // Life on the Mississippi
            3296,  // Confessions of St. Augustine
            5197,  // My Life (Wagner)
            15399, // Life of Olaudah Equiano
            408,   // The Souls of Black Folk
            852,   // Decline and Fall of the Roman Empire
            2680,  // Meditations (Marcus Aurelius)
            1228,  // On the Origin of Species
        ]),
        Genre(name: "Science", topic: "science", systemImage: "atom", bookIds: [
            1228,  // On the Origin of Species
            33283, // Calculus Made Easy
            5740,  // Tractatus Logico-Philosophicus
            4280,  // Critique of Pure Reason
            852,   // Decline and Fall of the Roman Empire
            3300,  // Wealth of Nations
            21279, // Flatland
            7142,  // History of the Peloponnesian War
            1946,  // On War
            815,   // Democracy in America
        ]),
        Genre(name: "Children's", topic: "children", systemImage: "face.smiling", bookIds: [
            11,    // Alice in Wonderland
            12,    // Through the Looking-Glass
            514,   // Little Women
            45,    // Anne of Green Gables
            55,    // Wizard of Oz
            16,    // Peter Pan
            2591,  // Grimm's Fairy Tales
            67098, // Winnie-the-Pooh
            1837,  // The Prince and the Pauper
            236,   // The Jungle Book
            74,    // Tom Sawyer
            120,   // Treasure Island
            730,   // Oliver Twist
            46,    // A Christmas Carol
            1260,  // Jane Eyre
            35,    // The Time Machine
        ]),
        Genre(name: "Short Stories", topic: "short stories", systemImage: "text.alignleft", bookIds: [
            36034, // White Nights (Dostoevsky)
            1952,  // The Yellow Wallpaper
            3090,  // Short Stories of Guy de Maupassant
            2148,  // Works of Edgar Allan Poe
            57333, // Short Stories by Chekhov
            8696,  // The Jew and Other Stories (Turgenev)
            2814,  // Dubliners
            41,    // Legend of Sleepy Hollow
            209,   // The Turn of the Screw
            1661,  // Adventures of Sherlock Holmes
            5200,  // Metamorphosis
            1952,  // The Yellow Wallpaper
            2852,  // Hound of the Baskervilles
        ]),
        Genre(name: "Drama", topic: "drama", systemImage: "theatermasks", bookIds: [
            1513,  // Romeo and Juliet
            100,   // Complete Works of Shakespeare
            2542,  // A Doll's House
            844,   // The Importance of Being Earnest
            1524,  // Hamlet
            27673, // Oedipus
            779,   // Doctor Faustus
            1515,  // Othello
            1533,  // Macbeth
            1526,  // Twelfth Night
            1522,  // A Midsummer Night's Dream
            4970,  // The Cherry Orchard
            5053,  // Uncle Vanya
        ]),
    ]
}
