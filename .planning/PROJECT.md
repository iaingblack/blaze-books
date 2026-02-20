# Blaze Books

## What This Is

An iOS app (iPhone and iPad) that lets users read ebooks using Rapid Serial Visual Presentation (RSVP) — displaying one word at a time at adjustable speeds — or in a full-page mode with word-by-word highlighting. Both modes optionally synchronize with Apple's text-to-speech so users can read and listen simultaneously, enhancing retention and focus. Users can import their own EPUBs or browse curated collections from Project Gutenberg.

## Core Value

Synchronized reading and listening — the voice tracks the displayed word perfectly, whether in RSVP or page mode, so users can read and hear content simultaneously without needing downloaded audiobooks.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Library view with shelves for organizing books
- [ ] Import user-owned EPUB files
- [ ] Browse and download books from curated Project Gutenberg lists
- [ ] RSVP reading mode (single word display at adjustable WPM)
- [ ] Page reading mode (full page with highlighted current word)
- [ ] Text-to-speech voiceover using AVSpeechSynthesizer
- [ ] Voice speed synced to match current WPM rate
- [ ] WPM slider (100-500 range) with voice speed cap at synthesizer limit
- [ ] Multiple Apple voice selection with on-demand voice pack download
- [ ] Table of contents navigation and chapter skip controls
- [ ] Per-book position tracking (remembers where you left off)
- [ ] "Continue reading" and "last read" sections in library
- [ ] iCloud sync of library, positions, and shelves across devices
- [ ] Offline-first — works without internet once books and voices downloaded
- [ ] Text-focused EPUB parsing (clean text extraction with chapter structure)

### Out of Scope

- In-app Gutenberg search — curated lists for v1, search deferred to v2
- Rich EPUB formatting (images, complex CSS, tables) — text-focused for v1
- Android or web support — iOS only
- Community-read audiobooks — synthetic voice only
- Social features, ratings, reviews

## Context

- RSVP ebook readers exist but none combine RSVP with synchronized TTS
- Competing apps with audiobook features use community-recorded audio (often poor quality)
- AVSpeechSynthesizer has a practical speed ceiling — voice should cap gracefully rather than degrade
- Project Gutenberg offers free public domain EPUBs with a well-documented catalog
- Target users: people who own EPUBs and want an audiobook-like experience without buying from Audible/iTunes, and speed readers who want audio reinforcement

## Constraints

- **Platform**: iOS 17+ (required for SwiftData)
- **UI Framework**: SwiftUI
- **Data Layer**: SwiftData with CloudKit for iCloud sync
- **Speech**: AVFoundation — AVSpeechSynthesizer
- **EPUB Parsing**: Text extraction with chapter structure only (no rich formatting)
- **WPM Range**: 100-500, voice caps at synthesizer maximum
- **Offline**: Must work fully offline once content and voice packs are downloaded

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI over UIKit | Modern declarative UI, good for new projects, first-class Apple support | — Pending |
| SwiftData + CloudKit over SQLite | Built-in iCloud sync, less manual work, Apple's modern data stack | — Pending |
| Text-focused EPUB parsing for v1 | Keeps scope lean, focuses effort on core reading/voice experience | — Pending |
| Curated Gutenberg lists over search | Simpler v1 scope, search can be added later | — Pending |
| Voice speed cap over degraded playback | Better UX to warn and disable than play garbled audio at extreme speeds | — Pending |

---
*Last updated: 2026-02-20 after initialization*
