# Phase 1: Foundation - Context

**Gathered:** 2026-02-20
**Status:** Ready for planning

<domain>
## Phase Boundary

EPUB import, parsing, word tokenization, chapter extraction, and CloudKit-compatible data model with reading position persistence. Users can import DRM-free EPUBs via the iOS Files app, see them in a library grid, and read them in a functional scaffold reading view that verifies parsing and position tracking work correctly.

</domain>

<decisions>
## Implementation Decisions

### Import experience
- Claude's discretion on trigger mechanism (in-app button + Files handler, or Files-only — pick what's right for Phase 1)
- Book appears in library grid immediately with inline progress indicator (spinner) that resolves to real cover and metadata when parsing completes
- After successful import, user stays in the library view — book appears with a subtle success indicator
- Duplicate detection: if the same EPUB is imported again, show "Already in your library" and skip — don't create a second copy

### Parsing failure UX
- When an EPUB has issues but text IS recoverable: import succeeds with a subtle warning toast ("Some formatting may not be perfect") that the user can dismiss
- When an EPUB is completely unreadable (corrupted, encrypted, no content): don't add to library — show a clear error message ("Couldn't open this book. It may be damaged or DRM-protected.")
- Partially broken books (some chapters fail): import with placeholder text for broken chapters ("This chapter could not be displayed")
- Chapter structure preserved even for broken chapters — table of contents shows all chapters, broken ones are navigable but show the placeholder message, chapter numbering matches the original EPUB

### Minimal reading view
- Functional scaffold: plain scrollable text with basic styling — looks like a real app but minimal, just enough to verify parsing and position tracking
- Chapter titles appear as styled headers within the scrollable text, giving structure
- Reading position auto-saves as the user scrolls — no manual bookmark needed — reopening lands at last read position
- Thin progress bar showing how far through the chapter/book the user is

### Book metadata
- Extract title, author, and cover image from the EPUB
- Smart fallbacks for missing metadata: missing title → use filename, missing author → show "Unknown Author", missing cover → generated placeholder with title text
- Library view is a grid layout (cover-forward, like Apple Books) — tapping a cover opens the book

### Claude's Discretion
- Import trigger mechanism (in-app button + Files handler vs. Files-only)
- Generated cover placeholder design (colored background with title, gradient, etc.)
- Exact progress bar positioning and style
- Loading/success indicator details
- Typography and spacing in the reading scaffold

</decisions>

<specifics>
## Specific Ideas

- Library grid should feel like Apple Books — covers front and center
- Inline progress during import (book appears immediately, resolves when done) rather than blocking modals
- Smart fallbacks should make the library feel populated even with imperfect EPUB metadata

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-20*
