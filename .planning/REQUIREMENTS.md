# Requirements: Blaze Books

**Defined:** 2026-02-20
**Core Value:** Synchronized reading and listening -- the voice tracks the displayed word perfectly, whether in RSVP or page mode

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### EPUB & Content

- [ ] **EPUB-01**: User can import DRM-free EPUB files via iOS Files app
- [ ] **EPUB-02**: App extracts clean text with chapter structure from EPUB files
- [ ] **EPUB-03**: App handles malformed EPUB XML gracefully without crashing
- [x] **EPUB-04**: Imported books work fully offline without internet connection

### Library

- [ ] **LIB-01**: User can view library with book covers and titles
- [ ] **LIB-02**: User can organize books into custom shelves
- [ ] **LIB-03**: User can remove books from library
- [ ] **LIB-04**: User sees "continue reading" section with recently read books
- [x] **LIB-05**: App auto-saves reading position per book

### Reading Modes

- [ ] **READ-01**: User can read in RSVP mode (single word display at set WPM)
- [ ] **READ-02**: User can read in page mode (full page with highlighted current word)
- [ ] **READ-03**: User can toggle between RSVP and page mode mid-session without losing position

### TTS & Voice

- [ ] **TTS-01**: User can enable text-to-speech that syncs with RSVP word display
- [ ] **TTS-02**: User can enable text-to-speech that syncs with page mode word highlighting
- [ ] **TTS-03**: Voice speed caps gracefully when WPM exceeds synthesizer capability
- [ ] **TTS-04**: User can choose from available Apple built-in voices
- [ ] **TTS-05**: User can download enhanced Apple voice packs on demand

### Controls & Navigation

- [ ] **NAV-01**: User can adjust reading speed via WPM slider (100-500 range)
- [ ] **NAV-02**: User can navigate via table of contents to jump between chapters
- [ ] **NAV-03**: User can skip to next/previous chapter with controls

### Book Discovery

- [ ] **DISC-01**: User can browse curated Project Gutenberg collections by genre
- [ ] **DISC-02**: User can download free books from Gutenberg directly in-app

### Appearance

- [ ] **APP-01**: App supports dark mode and light mode (follows system)
- [ ] **APP-02**: User can adjust font size for reading

### Sync

- [ ] **SYNC-01**: User's library syncs across devices via iCloud
- [ ] **SYNC-02**: User's reading positions sync across devices via iCloud
- [ ] **SYNC-03**: User's shelves sync across devices via iCloud

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Appearance

- **APP-03**: App supports sepia and custom color themes
- **APP-04**: User can choose from multiple reading fonts

### Library

- **LIB-06**: User can create named bookmarks within a book

### Book Discovery

- **DISC-03**: User can search full Project Gutenberg catalog in-app

### Analytics

- **STAT-01**: User can view reading statistics (WPM over time, books read)
- **STAT-02**: User can track reading streaks and goals

### Content

- **ANNOT-01**: User can highlight text in page mode
- **ANNOT-02**: User can add notes to highlighted text

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Rich EPUB rendering (images, CSS, tables) | Massive complexity; breaks RSVP which needs linear text; text-focused approach for v1 |
| AI/celebrity voices (ElevenLabs, etc.) | Expensive API costs, subscription pressure; Apple voices are free and improving |
| Social features (sharing, reviews, groups) | Orthogonal to core value; users have Goodreads/StoryGraph |
| Android / web support | iOS-only scope; SwiftUI + AVSpeechSynthesizer are Apple-only APIs |
| DRM-protected book support | Legally problematic; technically complex; DRM-free EPUB only |
| Real-time chat / community features | High complexity, not core to reading value |
| Full Gutenberg search | Curated lists for v1; dedicated Gutenberg apps already do full search well |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| EPUB-01 | Phase 1: Foundation | Pending |
| EPUB-02 | Phase 1: Foundation | Pending |
| EPUB-03 | Phase 1: Foundation | Pending |
| EPUB-04 | Phase 1: Foundation | Complete |
| LIB-05 | Phase 1: Foundation | Complete |
| READ-01 | Phase 2: Reading Engine | Pending |
| TTS-01 | Phase 2: Reading Engine | Pending |
| TTS-03 | Phase 2: Reading Engine | Pending |
| TTS-04 | Phase 2: Reading Engine | Pending |
| TTS-05 | Phase 2: Reading Engine | Pending |
| READ-02 | Phase 3: Reading Experience | Pending |
| READ-03 | Phase 3: Reading Experience | Pending |
| TTS-02 | Phase 3: Reading Experience | Pending |
| NAV-01 | Phase 3: Reading Experience | Pending |
| NAV-02 | Phase 4: Navigation & Appearance | Pending |
| NAV-03 | Phase 4: Navigation & Appearance | Pending |
| APP-01 | Phase 4: Navigation & Appearance | Pending |
| APP-02 | Phase 4: Navigation & Appearance | Pending |
| LIB-01 | Phase 5: Library | Pending |
| LIB-02 | Phase 5: Library | Pending |
| LIB-03 | Phase 5: Library | Pending |
| LIB-04 | Phase 5: Library | Pending |
| DISC-01 | Phase 6: Book Discovery | Pending |
| DISC-02 | Phase 6: Book Discovery | Pending |
| SYNC-01 | Phase 7: iCloud Sync | Pending |
| SYNC-02 | Phase 7: iCloud Sync | Pending |
| SYNC-03 | Phase 7: iCloud Sync | Pending |

**Coverage:**
- v1 requirements: 27 total
- Mapped to phases: 27
- Unmapped: 0

---
*Requirements defined: 2026-02-20*
*Last updated: 2026-02-20 after roadmap creation*
