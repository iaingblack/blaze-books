# Roadmap: Blaze Books

## Overview

Blaze Books delivers an iOS reading app where synchronized text-to-speech tracks the displayed word in both RSVP and page modes. The build follows the dependency chain: EPUB parsing and data models first (everything depends on clean tokenized text), then the reading engine (the core differentiator), then reading views and controls, then library management, Gutenberg integration, and finally iCloud sync. Each phase delivers a coherent capability that can be verified independently.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Data models, EPUB parsing, word tokenization, and file import
- [x] **Phase 2: Reading Engine** - RSVP engine, TTS service, synchronization coordinator, and voice management
- [x] **Phase 3: Reading Experience** - RSVP and page mode views, mode switching, TTS page sync, and speed control
- [ ] **Phase 4: Navigation & Appearance** - Table of contents, chapter skip controls, dark mode, and font size
- [ ] **Phase 5: Library** - Library grid, shelves, book management, and continue reading
- [ ] **Phase 6: Book Discovery** - Curated Project Gutenberg collections and in-app download
- [ ] **Phase 7: iCloud Sync** - Cross-device sync of library, reading positions, and shelves

## Phase Details

### Phase 1: Foundation
**Goal**: Users can import EPUBs that are reliably parsed into clean, tokenized text with chapter structure, persisted in a CloudKit-compatible data model
**Depends on**: Nothing (first phase)
**Requirements**: EPUB-01, EPUB-02, EPUB-03, EPUB-04, LIB-05
**Success Criteria** (what must be TRUE):
  1. User can import a DRM-free EPUB via the iOS Files app and see it appear in the app
  2. Imported book displays correct chapter structure (chapter titles and count match the EPUB)
  3. A malformed EPUB (bad XML, HTML entities) imports without crashing and shows readable text
  4. An imported book works fully offline after initial import (no network calls during reading)
  5. App remembers reading position per book across app restarts
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Xcode project setup, SwiftData models with VersionedSchema, Readium SPM dependency
- [x] 01-02-PLAN.md — EPUB import service, Readium parser service, word tokenizer
- [x] 01-03-PLAN.md — Library grid view, reading view with position tracking, end-to-end wiring

### Phase 2: Reading Engine
**Goal**: The synchronization engine keeps TTS audio locked to visual word display, with voice selection and graceful speed capping
**Depends on**: Phase 1
**Requirements**: TTS-01, TTS-03, TTS-04, TTS-05, READ-01
**Success Criteria** (what must be TRUE):
  1. User can read in RSVP mode with words displayed one at a time at the configured WPM
  2. User can enable TTS and hear audio that tracks the displayed RSVP word with no perceptible drift
  3. When WPM exceeds the synthesizer's capability, voice speed caps gracefully and the user is informed rather than hearing garbled audio
  4. User can choose from available Apple built-in voices and hear a preview
  5. User can download enhanced Apple voice packs from within the app's settings
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — RSVPEngine with ORP positioning and TTSService with sentence-level chunking
- [x] 02-02-PLAN.md — ReadingCoordinator, SpeedCapService, and VoiceManager
- [x] 02-03-PLAN.md — RSVP display view, voice picker, speed cap banner, and ReadingView integration

### Phase 3: Reading Experience
**Goal**: Users have two complete reading modes (RSVP and page) with synchronized TTS and can switch between them without losing their place
**Depends on**: Phase 2
**Requirements**: READ-02, READ-03, TTS-02, NAV-01
**Success Criteria** (what must be TRUE):
  1. User can read in page mode and see the current word highlighted as TTS speaks it
  2. User can toggle between RSVP and page mode mid-session and resume at the exact same word
  3. User can adjust reading speed via a WPM slider (100-500 range) and see the change take effect immediately
  4. TTS audio in page mode stays synchronized with word highlighting throughout an entire chapter
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — ReadingMode enum, PageTextService (paragraph splitting, word-to-paragraph mapping, AttributedString highlighting), ReadingCoordinator extensions (mode switching, debounced WPM)
- [x] 03-02-PLAN.md — PageModeView (scrollable text with word highlighting and auto-scroll), WPMSliderView, ReadingView integration with mode switching

### Phase 4: Navigation & Appearance
**Goal**: Users can navigate books by chapter and customize the reading appearance for comfort
**Depends on**: Phase 3
**Requirements**: NAV-02, NAV-03, APP-01, APP-02
**Success Criteria** (what must be TRUE):
  1. User can open a table of contents and jump to any chapter
  2. User can skip to the next or previous chapter using on-screen controls
  3. App follows the system dark mode / light mode setting automatically
  4. User can increase or decrease font size for reading and see it apply immediately
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Library
**Goal**: Users can browse, organize, and manage their book collection with a polished library experience
**Depends on**: Phase 1
**Requirements**: LIB-01, LIB-02, LIB-03, LIB-04
**Success Criteria** (what must be TRUE):
  1. User sees a library view with book covers (or placeholders) and titles
  2. User can create custom shelves and organize books into them
  3. User can remove a book from their library
  4. User sees a "continue reading" section showing recently read books with progress
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: Book Discovery
**Goal**: Users can discover and download free public domain books without leaving the app
**Depends on**: Phase 5
**Requirements**: DISC-01, DISC-02
**Success Criteria** (what must be TRUE):
  1. User can browse curated Project Gutenberg collections organized by genre
  2. User can download a free book from Gutenberg and it appears in their library ready to read
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

### Phase 7: iCloud Sync
**Goal**: Users can read on one device and continue seamlessly on another
**Depends on**: Phase 5
**Requirements**: SYNC-01, SYNC-02, SYNC-03
**Success Criteria** (what must be TRUE):
  1. User's library (book list and metadata) syncs across devices via iCloud
  2. User's reading positions sync so they can continue on another device where they left off
  3. User's custom shelves sync across devices via iCloud
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7
Note: Phase 5 depends on Phase 1 (not Phase 4), so Phases 5-7 could overlap with Phases 3-4 if desired.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2026-02-20 |
| 2. Reading Engine | 3/3 | Complete    | 2026-02-20 |
| 3. Reading Experience | 2/2 | Complete | 2026-02-20 |
| 4. Navigation & Appearance | 0/2 | Not started | - |
| 5. Library | 0/2 | Not started | - |
| 6. Book Discovery | 0/1 | Not started | - |
| 7. iCloud Sync | 0/2 | Not started | - |
