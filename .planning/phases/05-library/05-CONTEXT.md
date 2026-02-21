# Phase 5: Library - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can browse, organize, and manage their book collection with a polished library experience. Covers LIB-01 (library view with covers/titles), LIB-02 (custom shelves), LIB-03 (remove books), and LIB-04 (continue reading with progress). Builds on the existing LibraryView from Phase 1.

</domain>

<decisions>
## Implementation Decisions

### Library home layout
- Vertically stacked sections: Continue Reading at top, then shelf sections, then "All Books" grid at bottom (Apple Books style)
- Shelves displayed as collapsible sections with book cover grids inside
- Sort menu in toolbar for All Books grid: recent, title, author, date added
- Tapping a book in All Books grid opens reading view (existing behavior preserved)

### Shelf management
- New shelf created via toolbar button that prompts for a name
- Books added to shelves via long-press context menu on book cover -> "Add to Shelf" -> pick from list
- A book can belong to multiple shelves (shelves behave like tags, not folders)
- Shelves can be renamed and deleted
- Deleting a shelf does not delete the books in it

### Book deletion flow
- Deletion initiated via long-press context menu (same menu as shelf management)
- Always show confirmation dialog: "Delete [Book Title]?" with destructive-styled button
- Deletion removes both the SwiftData record AND the EPUB file from disk
- No bulk delete — one book at a time via context menu
- Deletion also removes the book from all shelves it belongs to

### Continue reading section
- Shows any book with reading progress > 0% (not time-gated)
- Limited to 3-4 most recently read books
- Progress displayed as both a thin progress bar under the cover AND a percentage text label
- Tapping a continue-reading book goes straight to the reading view (no detail screen)

### Claude's Discretion
- Whether tapping a shelf section header navigates to a dedicated full-screen shelf view
- Exact spacing, typography, and animation for collapsible sections
- Sort menu icon and presentation style
- Continue reading section header design
- How shelf name input is presented (alert vs sheet)

</decisions>

<specifics>
## Specific Ideas

- Long-press context menu is the unified interaction point for book management (add to shelf, delete)
- Continue reading section should feel like a quick-resume area — minimal friction to get back to reading
- Collapsible shelf sections keep the single-screen library browsable without tab switching

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-library*
*Context gathered: 2026-02-21*
