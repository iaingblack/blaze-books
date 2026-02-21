# Phase 5: Library - Research

**Researched:** 2026-02-21
**Domain:** SwiftUI library management UI, SwiftData schema evolution, collection views
**Confidence:** HIGH

## Summary

Phase 5 transforms the existing flat `LibraryView` (a single grid of all books sorted by import date) into a rich, sectioned library experience with continue reading, custom shelves, book deletion, and sort options. The primary technical challenges are: (1) adding a new `Shelf` model with a many-to-many relationship to `Book` via SwiftData schema migration, (2) restructuring LibraryView from a single `LazyVGrid` into vertically stacked sections with collapsible shelf groups, and (3) implementing context menus and confirmation dialogs for book management actions.

The existing codebase is well-structured for this work. The `SchemaV1` versioned schema and `BlazeBooksMigrationPlan` are already in place, `FileStorageManager.deleteFile` exists for EPUB cleanup, `Book.readingPosition` tracks `chapterIndex`/`wordIndex`/`lastReadDate` which provides all data needed for continue reading, and `BookCoverView` is a reusable component ready for use across all sections. The cascade delete rules on Book -> Chapter and Book -> ReadingPosition mean SwiftData handles related record cleanup automatically.

**Primary recommendation:** Create SchemaV2 adding a `Shelf` model with many-to-many Book relationship using `@Relationship(inverse:)` on both sides, add a lightweight migration stage, then restructure LibraryView into stacked sections (Continue Reading, per-shelf collapsible sections, All Books grid) with `.contextMenu` on each `BookCoverView` for shelf assignment and deletion.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Vertically stacked sections: Continue Reading at top, then shelf sections, then "All Books" grid at bottom (Apple Books style)
- Shelves displayed as collapsible sections with book cover grids inside
- Sort menu in toolbar for All Books grid: recent, title, author, date added
- Tapping a book in All Books grid opens reading view (existing behavior preserved)
- New shelf created via toolbar button that prompts for a name
- Books added to shelves via long-press context menu on book cover -> "Add to Shelf" -> pick from list
- A book can belong to multiple shelves (shelves behave like tags, not folders)
- Shelves can be renamed and deleted
- Deleting a shelf does not delete the books in it
- Deletion initiated via long-press context menu (same menu as shelf management)
- Always show confirmation dialog: "Delete [Book Title]?" with destructive-styled button
- Deletion removes both the SwiftData record AND the EPUB file from disk
- No bulk delete -- one book at a time via context menu
- Deletion also removes the book from all shelves it belongs to
- Continue reading shows any book with reading progress > 0% (not time-gated)
- Limited to 3-4 most recently read books
- Progress displayed as both a thin progress bar under the cover AND a percentage text label
- Tapping a continue-reading book goes straight to the reading view (no detail screen)

### Claude's Discretion
- Whether tapping a shelf section header navigates to a dedicated full-screen shelf view
- Exact spacing, typography, and animation for collapsible sections
- Sort menu icon and presentation style
- Continue reading section header design
- How shelf name input is presented (alert vs sheet)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIB-01 | User can view library with book covers and titles | Restructured LibraryView with stacked sections, BookCoverView reuse, LazyVGrid patterns, sort menu |
| LIB-02 | User can organize books into custom shelves | Shelf model with many-to-many relationship, context menu "Add to Shelf", DisclosureGroup collapsible sections |
| LIB-03 | User can remove books from library | Context menu with destructive button, confirmation dialog, SwiftData cascade delete + FileStorageManager.deleteFile |
| LIB-04 | User sees "continue reading" section with recently read books | ReadingPosition.lastReadDate sort, progress computation from chapterIndex/wordIndex/chapterCount, ProgressView bar + percentage label |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All UI components (LazyVGrid, DisclosureGroup, contextMenu, confirmationDialog, Menu) | Project framework, all needed APIs available in iOS 17+ |
| SwiftData | iOS 17+ | Shelf model, many-to-many relationships, @Query with sort/filter, schema migration | Project data layer, VersionedSchema + lightweight migration for adding Shelf model |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| FileStorageManager | (existing) | Delete EPUB files from disk during book removal | Already has `deleteFile(_:)` method ready to use |
| BookCoverView | (existing) | Reusable book cover display component | Used across Continue Reading, shelf sections, and All Books grid |
| ReadingPositionService | (existing) | Progress computation from chapterIndex/wordIndex | Reference for progress calculation logic in continue reading section |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DisclosureGroup for shelves | Custom expand/collapse with animation | DisclosureGroup is built-in and sufficient; custom only needed for unusual visual requirements |
| `.contextMenu` modifier | Custom long-press gesture + popover | contextMenu is native iOS long-press pattern, correct for this use case |
| `confirmationDialog` for delete | `alert` modifier | confirmationDialog is the correct pattern for destructive confirmations on iOS (action sheet style) |
| `Menu` in toolbar for sort | `Picker` with menu style | Menu is simpler for action-style sort selection with checkmarks |

## Architecture Patterns

### Recommended Project Structure
```
BlazeBooks/
├── Models/
│   ├── SchemaV1.swift          # Existing (unchanged)
│   ├── SchemaV2.swift          # NEW: adds Shelf model
│   ├── Book.swift              # Existing typealias
│   ├── Chapter.swift           # Existing typealias
│   ├── ReadingPosition.swift   # Existing typealias
│   └── Shelf.swift             # NEW: typealias Shelf = SchemaV2.Shelf
├── Views/
│   └── Library/
│       ├── LibraryView.swift       # REWRITE: stacked sections layout
│       ├── BookCoverView.swift     # MODIFY: add context menu, progress bar variant
│       ├── ContinueReadingSection.swift  # NEW: horizontal scroll of recently read books
│       ├── ShelfSectionView.swift  # NEW: collapsible shelf section with book grid
│       └── AllBooksGridView.swift  # NEW: sortable grid of all books (extracted from current LibraryView)
├── Services/
│   └── LibraryService.swift    # NEW: book deletion logic (SwiftData + file cleanup)
```

### Pattern 1: SwiftData Schema Migration (V1 -> V2)
**What:** Add a new `Shelf` model with many-to-many relationship to Book using VersionedSchema and lightweight migration.
**When to use:** When evolving the data model to add new entities.
**Example:**
```swift
// Source: Apple Developer Documentation - SwiftData Schema Migration
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Book.self, Chapter.self, ReadingPosition.self, Shelf.self
    ]

    // Book, Chapter, ReadingPosition: copy from V1 with Shelf relationship added to Book
    @Model final class Book {
        // ... all existing V1 properties ...
        @Relationship(deleteRule: .nullify, inverse: \Shelf.books)
        var shelves: [Shelf]? = []
    }

    @Model final class Shelf {
        var id: UUID = UUID()
        var name: String = ""
        var createdDate: Date = Date()
        var sortOrder: Int = 0
        @Relationship(deleteRule: .nullify)
        var books: [Shelf.Book]? = []  // use the V2 Book type
    }
}

enum BlazeBooksMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    ]
}
```

### Pattern 2: Many-to-Many Relationship (Book <-> Shelf)
**What:** Both Book and Shelf hold arrays of the other, with `@Relationship(inverse:)` on one side to make the relationship explicit.
**When to use:** Shelves behave like tags -- a book can be in multiple shelves, a shelf contains multiple books.
**Example:**
```swift
// Source: hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships
// In Shelf model:
@Relationship(deleteRule: .nullify) var books: [Book]? = []

// In Book model:
@Relationship(deleteRule: .nullify, inverse: \Shelf.books) var shelves: [Shelf]? = []
```
**Critical:** Use `.nullify` delete rule on BOTH sides -- deleting a shelf should NOT delete books, and deleting a book should just remove it from shelves. Default arrays to `[]` to avoid the iOS 17.0 alphabetical ordering bug.

### Pattern 3: Context Menu with Multiple Actions
**What:** Long-press context menu on book covers providing "Add to Shelf" submenu and "Delete" action.
**When to use:** When a single interaction point handles multiple book management actions.
**Example:**
```swift
// Source: Apple Developer Documentation - SwiftUI contextMenu
BookCoverView(book: book)
    .contextMenu {
        // Shelf assignment submenu
        Menu("Add to Shelf") {
            ForEach(shelves) { shelf in
                Button {
                    addBookToShelf(book, shelf)
                } label: {
                    Label(shelf.name,
                          systemImage: bookIsInShelf(book, shelf) ? "checkmark" : "")
                }
            }
        }
        // Delete action
        Button(role: .destructive) {
            bookToDelete = book
            showDeleteConfirmation = true
        } label: {
            Label("Delete Book", systemImage: "trash")
        }
    }
```

### Pattern 4: Confirmation Dialog for Destructive Actions
**What:** Action sheet-style confirmation before book deletion.
**When to use:** Always before permanently deleting a book and its EPUB file.
**Example:**
```swift
// Source: Apple Developer Documentation - SwiftUI confirmationDialog
.confirmationDialog(
    "Delete \(bookToDelete?.title ?? "Book")?",
    isPresented: $showDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete Book", role: .destructive) {
        if let book = bookToDelete {
            deleteBook(book)
        }
    }
} message: {
    Text("This will permanently remove the book and its file.")
}
```

### Pattern 5: Collapsible Shelf Sections with DisclosureGroup
**What:** Each shelf renders as a collapsible section with a book cover grid inside.
**When to use:** For the shelf sections between Continue Reading and All Books.
**Example:**
```swift
// Source: Apple Developer Documentation - SwiftUI DisclosureGroup
@State private var shelfExpanded: [UUID: Bool] = [:]

ForEach(shelves) { shelf in
    DisclosureGroup(
        isExpanded: Binding(
            get: { shelfExpanded[shelf.id] ?? true },
            set: { shelfExpanded[shelf.id] = $0 }
        )
    ) {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(shelf.books ?? []) { book in
                NavigationLink(value: book) {
                    BookCoverView(book: book)
                }
            }
        }
    } label: {
        Text(shelf.name)
            .font(.title3).bold()
    }
}
```

### Pattern 6: Continue Reading Progress Computation
**What:** Compute overall reading progress percentage from ReadingPosition's chapterIndex, wordIndex, and Book's chapter data.
**When to use:** For the continue reading section's progress bar and percentage label.
**Example:**
```swift
// Derived from existing ReadingPositionService.updateProgressFromPosition logic
func computeOverallProgress(for book: Book) -> Double {
    guard let position = book.readingPosition else { return 0.0 }
    let chapters = (book.chapters ?? []).sorted { $0.index < $1.index }
    let totalChapters = chapters.count
    guard totalChapters > 0 else { return 0.0 }

    var chapterProgress = 0.0
    if position.chapterIndex < chapters.count {
        let chapter = chapters[position.chapterIndex]
        if chapter.wordCount > 0 {
            chapterProgress = Double(position.wordIndex) / Double(chapter.wordCount)
        }
    }

    let chapterWeight = 1.0 / Double(totalChapters)
    return (Double(position.chapterIndex) * chapterWeight) + (chapterProgress * chapterWeight)
}
```

### Pattern 7: Sort Options for All Books Grid
**What:** A Menu in the toolbar allowing sort selection with visual checkmark indicator.
**When to use:** The All Books grid needs sorting by recent, title, author, date added.
**Example:**
```swift
enum BookSortOption: String, CaseIterable {
    case recent = "Recently Read"
    case title = "Title"
    case author = "Author"
    case dateAdded = "Date Added"
}

@State private var sortOption: BookSortOption = .recent

// In toolbar:
Menu {
    ForEach(BookSortOption.allCases, id: \.self) { option in
        Button {
            sortOption = option
        } label: {
            if sortOption == option {
                Label(option.rawValue, systemImage: "checkmark")
            } else {
                Text(option.rawValue)
            }
        }
    }
} label: {
    Image(systemName: "arrow.up.arrow.down")
}
```

### Anti-Patterns to Avoid
- **Mutating many-to-many arrays before insertion:** SwiftData crashes with "illegal attempt to establish a relationship" if you modify relationship arrays on objects that haven't been inserted into a context yet. Always insert both objects first, then assign the relationship.
- **Using @Query with complex predicates for sorted/filtered subsets:** For the continue reading section, filter and sort in-view from a single @Query rather than creating multiple @Query properties with complex predicates -- keeps the view simpler and avoids predicate limitations with relationships.
- **Cascade delete on many-to-many:** Using `.cascade` on the Shelf->Book relationship would delete books when a shelf is deleted. Must use `.nullify` on both sides of the many-to-many.
- **Storing overallProgress in the model:** The ReadingPosition already has chapterIndex + wordIndex; computing progress at display time avoids sync issues and matches the existing pattern in ReadingPositionService.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Collapsible sections | Custom expand/collapse animation | `DisclosureGroup` | Native component with accessibility support, expansion state binding |
| Context menus | Custom long-press gesture recognizer | `.contextMenu { }` modifier | System-standard haptics, preview, animation; matches iOS UX expectations |
| Destructive confirmation | Custom modal/alert | `.confirmationDialog` | Action sheet style is the correct iOS pattern for destructive actions |
| Sort menu | Custom popover | `Menu { }` in toolbar | Native dropdown with checkmark support |
| Many-to-many relationship | Manual join table | SwiftData `@Relationship(inverse:)` with arrays on both sides | SwiftData manages the join table internally |
| Schema migration | Manual database migration | `VersionedSchema` + `MigrationStage.lightweight` | Adding a new model with default values is a lightweight migration |

**Key insight:** Every UI interaction in this phase (context menu, confirmation dialog, collapsible sections, sort menu) has a native SwiftUI component that matches the iOS platform conventions exactly. Using custom solutions would deviate from user expectations and add unnecessary complexity.

## Common Pitfalls

### Pitfall 1: SwiftData Many-to-Many Alphabetical Bug (iOS 17.0)
**What goes wrong:** Many-to-many relationships can fail silently or crash based on the alphabetical ordering of model class names in iOS 17.0.
**Why it happens:** Known SwiftData bug in the initial iOS 17.0 release.
**How to avoid:** Always provide default empty array values for relationship properties: `var shelves: [Shelf]? = []` and `var books: [Book]? = []`. This workaround is confirmed to resolve the issue.
**Warning signs:** Unexplained crashes when adding books to shelves, or shelves appearing empty after assignment.

### Pitfall 2: Inserting Before Relating
**What goes wrong:** "Illegal attempt to establish a relationship" crash when assigning books to shelves.
**Why it happens:** SwiftData requires objects to be inserted into a ModelContext before relationship arrays are mutated.
**How to avoid:** When creating a new shelf, insert it into the context FIRST, then append books. When adding a book to a shelf, both must already be in the context (they will be, since both are fetched via @Query).
**Warning signs:** Crashes on the line that modifies a relationship array.

### Pitfall 3: File Deletion Without SwiftData Cleanup
**What goes wrong:** Orphaned SwiftData records pointing to deleted files, or orphaned files without records.
**Why it happens:** Deleting the EPUB file and the SwiftData record are two separate operations that can fail independently.
**How to avoid:** Delete the SwiftData record first (with cascade to chapters and reading position), then delete the file. If file deletion fails, log a warning but don't re-insert the record -- an orphaned file is less harmful than an orphaned record that crashes the app.
**Warning signs:** Books appearing in library with no cover, crashes when opening a deleted book.

### Pitfall 4: DisclosureGroup State Loss on Rerender
**What goes wrong:** Shelf sections collapse unexpectedly when the view re-renders (e.g., after adding a book to a shelf).
**Why it happens:** If expansion state is derived from the shelf array (ForEach), SwiftUI may recreate the DisclosureGroup, losing local @State.
**How to avoid:** Store expansion state in a dictionary keyed by shelf UUID: `@State private var shelfExpanded: [UUID: Bool] = [:]`. Use a `Binding` wrapper in the ForEach.
**Warning signs:** Sections collapsing after any book management action.

### Pitfall 5: Sort Options Not Applied Dynamically
**What goes wrong:** Changing sort option doesn't update the displayed order.
**Why it happens:** `@Query` sort descriptors are compile-time. Dynamic sorting requires either multiple @Query properties or post-fetch sorting.
**How to avoid:** Use a single `@Query` that fetches all books, then apply sorting in a computed property based on the current sort option. This is simpler and more flexible than trying to dynamically change @Query parameters.
**Warning signs:** Sort menu selection changes but grid order doesn't update.

### Pitfall 6: Continue Reading Showing Books at 0%
**What goes wrong:** Freshly imported books appear in continue reading despite having no reading progress.
**Why it happens:** ReadingPosition is created at import time with chapterIndex=0, wordIndex=0. If the filter only checks for position existence, all books qualify.
**How to avoid:** Filter by `readingPosition.wordIndex > 0 || readingPosition.chapterIndex > 0` to exclude books that have never been opened past the starting position. A book at chapter 0, word 0 has 0% progress and should not appear.
**Warning signs:** Newly imported books immediately showing up in "Continue Reading" section.

## Code Examples

Verified patterns from official sources:

### Book Deletion with File Cleanup
```swift
// Combines SwiftData cascade delete with FileStorageManager file removal
func deleteBook(_ book: Book, modelContext: ModelContext) {
    let filePath = book.filePath

    // 1. Remove from all shelves (nullify handles this via relationship)
    // SwiftData's .nullify delete rule automatically removes book from shelf.books arrays

    // 2. Delete SwiftData record (cascades to chapters and reading position)
    modelContext.delete(book)

    // 3. Delete EPUB file from disk
    do {
        try FileStorageManager.deleteFile(filePath)
    } catch {
        print("[LibraryService] Warning: Could not delete file '\(filePath)': \(error)")
        // File cleanup failure is non-fatal -- record is already deleted
    }
}
```

### Continue Reading Query and Filter
```swift
// Fetch books with reading progress, sorted by most recently read
@Query(sort: \Book.importDate, order: .reverse) private var allBooks: [Book]

private var continueReadingBooks: [Book] {
    allBooks
        .filter { book in
            guard let pos = book.readingPosition else { return false }
            return pos.chapterIndex > 0 || pos.wordIndex > 0
        }
        .sorted { a, b in
            (a.readingPosition?.lastReadDate ?? .distantPast) >
            (b.readingPosition?.lastReadDate ?? .distantPast)
        }
        .prefix(4)  // Limited to 3-4 most recently read
        .map { $0 }  // Convert ArraySlice to Array
}
```

### Shelf Name Input via Alert
```swift
// Simple alert with TextField for shelf name input
@State private var showNewShelfAlert = false
@State private var newShelfName = ""

.alert("New Shelf", isPresented: $showNewShelfAlert) {
    TextField("Shelf name", text: $newShelfName)
    Button("Create") {
        createShelf(name: newShelfName)
        newShelfName = ""
    }
    Button("Cancel", role: .cancel) {
        newShelfName = ""
    }
} message: {
    Text("Enter a name for your new shelf.")
}
```

### Adding Book to Shelf
```swift
// Both objects are already in the context (fetched via @Query)
func addBookToShelf(_ book: Book, _ shelf: Shelf) {
    if !(shelf.books?.contains(where: { $0.id == book.id }) ?? false) {
        shelf.books?.append(book)
    }
}

func removeBookFromShelf(_ book: Book, _ shelf: Shelf) {
    shelf.books?.removeAll(where: { $0.id == book.id })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Core Data NSManagedObject | SwiftData @Model with VersionedSchema | iOS 17 (2023) | Simpler model definitions, built-in migration support |
| UIKit UIContextMenuInteraction | SwiftUI `.contextMenu` modifier | SwiftUI 2.0 (2020) | Declarative, no delegate pattern needed |
| UIAlertController action sheets | SwiftUI `.confirmationDialog` modifier | SwiftUI 3.0 (2021) | Declarative, automatic dismiss handling |
| Manual expand/collapse with @State | SwiftUI `DisclosureGroup` | SwiftUI 2.0 (2020) | Built-in accessibility, standard chevron indicator |

**Deprecated/outdated:**
- `Alert(title:message:primaryButton:secondaryButton:)` init is deprecated in favor of `.alert` view modifier with ViewBuilder actions (iOS 15+)

## Open Questions

1. **DisclosureGroup styling within ScrollView**
   - What we know: DisclosureGroup works inside ScrollView and Form. In a plain ScrollView context, it may need custom styling to look like section headers rather than form rows.
   - What's unclear: Whether the default DisclosureGroup style inside a ScrollView matches the Apple Books visual style, or if a custom `DisclosureGroupStyle` is needed.
   - Recommendation: Start with default styling; create custom style only if it looks off. Claude's discretion covers exact styling.

2. **@Query dynamic sort descriptors**
   - What we know: SwiftData `@Query` sort descriptors are set at init time. Changing sort at runtime requires a different approach.
   - What's unclear: Whether iOS 17 supports `@Query` with dynamic `SortDescriptor` binding, or if post-fetch sorting is required.
   - Recommendation: Use post-fetch sorting in a computed property. This is simpler, works reliably, and the book count is small enough that performance is not a concern.

3. **Shelf ordering**
   - What we know: User can create, rename, and delete shelves. CONTEXT.md does not specify shelf ordering.
   - What's unclear: Whether shelves should be ordered by creation date, alphabetically, or user-defined order.
   - Recommendation: Default to creation date order (natural order of appearance). A `sortOrder` property on Shelf enables future reordering if needed.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - SwiftUI contextMenu: `contextMenu(menuItems:preview:)` modifier API and usage patterns
- Apple Developer Documentation - SwiftData MigrationStage: `MigrationStage.lightweight(fromVersion:toVersion:)` and `SchemaMigrationPlan` protocol
- Apple Developer Documentation - SwiftUI DisclosureGroup: `init(_:isExpanded:content:)` and custom `DisclosureGroupStyle`
- Apple Developer Documentation - SwiftUI confirmationDialog: destructive button patterns with `role: .destructive`
- Apple Developer Documentation - SwiftData @Query: predicate and sort descriptor initialization
- Apple Developer Documentation - SwiftData @Relationship: `deleteRule: .cascade` and `deleteRule: .nullify` patterns

### Secondary (MEDIUM confidence)
- [Hacking with Swift - Many-to-Many Relationships](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships) - Verified pattern: arrays on both sides with `@Relationship(inverse:)`, iOS 17.0 alphabetical bug workaround
- [Hacking with Swift - Schema Migration](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) - Confirmed: adding new model with default values is lightweight migration
- [Fat Bob Man - SwiftData Relationships](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/) - Additional detail on relationship behavior and pitfalls

### Tertiary (LOW confidence)
- None -- all findings verified with primary or secondary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All APIs are native SwiftUI/SwiftData iOS 17+, verified via Context7/Apple docs
- Architecture: HIGH - Patterns directly derived from existing codebase (SchemaV1, BookCoverView, FileStorageManager) and verified Apple docs
- Pitfalls: HIGH - Many-to-many bugs and insertion ordering documented across multiple sources; deletion patterns verified against existing FileStorageManager code

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable -- iOS 17+ SwiftUI/SwiftData APIs are mature)
