# Phase 6: Book Discovery - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can discover and download free public domain books from Project Gutenberg without leaving the app. Browsing curated genre collections and downloading EPUBs that auto-import into the library. Search/filtering beyond genre browsing is out of scope (DISC-03 is backlog).

</domain>

<decisions>
## Implementation Decisions

### Collection Presentation
- Genre grid layout — tap a genre card to see its books
- Genre cards show a small collage of 2-3 book covers from that genre with the genre name overlaid
- Books within a genre displayed as a book cover grid (matching the library layout style)
- Discovery accessed via a button/section within the Library view (not a separate tab)

### Book Detail & Preview
- Minimal detail view: cover, title, author, and Download button
- Info button available to expand/reveal additional summary information
- Presented as a sheet (half/full) sliding up over the genre grid
- Books already in the user's library show an "In Library" badge instead of Download button
- Cover images sourced from Gutenberg metadata, with placeholder fallback

### Download Experience
- Download button transforms into inline progress indicator, then shows "In Library" when complete
- No "Read Now" offer after download — just confirms with the badge, user navigates to Library when ready
- Downloaded EPUBs go through the existing EPUB import pipeline (same parsing/chapter extraction)
- On network failure, show error state on the download button with a "Retry" option

### Curation Approach
- Live queries to Gutenberg API by genre/subject (not bundled JSON)
- Broad genre set (~12-15 categories): Fiction, Science Fiction, Mystery, Philosophy, Science, History, Poetry, Adventure, Biography, Drama, Horror, Children's, Religion, etc.
- Default sort by Gutenberg download count (most popular first), no additional sort options
- Infinite scroll within a genre (keep loading as user scrolls)
- English-language books only (matches RSVP reader's NLLanguage.english tokenization)

### Claude's Discretion
- Exact genre list and Gutenberg subject-to-genre mapping
- Genre card visual design details (shadows, corner radius, overlay styling)
- Loading/skeleton states while API responses arrive
- Caching strategy for API responses
- Exact Gutenberg API endpoint selection and pagination implementation

</decisions>

<specifics>
## Specific Ideas

- Genre cards with cover collages give a visual preview of what's inside each collection
- The sheet presentation for book details keeps browsing lightweight — quick to dismiss and return to the grid
- Reusing the existing EPUB import pipeline ensures downloaded books work identically to file-imported ones (chapters, tokenization, reading positions)

</specifics>

<deferred>
## Deferred Ideas

- DISC-03: Full-text search of Project Gutenberg catalog — backlog item, not in v1.0 scope

</deferred>

---

*Phase: 06-book-discovery*
*Context gathered: 2026-02-21*
