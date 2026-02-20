# Feature Research

**Domain:** iOS RSVP ebook reader with synchronized TTS
**Researched:** 2026-02-20
**Confidence:** MEDIUM — based on competitive analysis of 15+ iOS apps across RSVP speed reading, TTS reading, and general ebook reader categories. No single competitor combines RSVP + synchronized TTS, which validates the core differentiator but means less direct comparison data exists.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| EPUB import (user-owned files) | Every ebook reader supports this. Users have existing EPUB collections. Without it, zero content on day one. | MEDIUM | DRM-free only. Need robust EPUB parser for text extraction with chapter structure. Glance, Outread, BookFusion all support this as baseline. |
| Reading position persistence | Every reader saves where you left off. Losing position is a deal-breaker. | LOW | Per-book position stored locally. SwiftData model with book ID + position. All competitors do this. |
| Adjustable WPM speed | Core to RSVP. Every RSVP app (Outread, Glance, RSVP Reader, Rapid Reader) has this. Users expect granular control. | LOW | Slider or stepper, 100-500 WPM for v1. Most competitors go 100-1000+. Cap at 500 is fine since TTS cannot keep up beyond ~300. |
| Basic library view | Users need to see and find their books. Flat list at minimum, shelves expected. | MEDIUM | BookShelves, BookFusion, Voice Dream all provide organized library with covers, sorting, filtering. Need at least cover thumbnails + title list. |
| Bookmarks / save position | Users expect to mark multiple spots, not just current position. Standard in all ebook readers. | LOW | Distinct from auto-save position. Let users create named bookmarks within a book. |
| Offline reading | Once a book is imported, it must work without internet. Every serious reader app works offline. | LOW | Straightforward — EPUBs are local files. The complexity is in offline voice packs (see TTS). |
| Table of contents navigation | Users expect to jump to chapters. Standard in every EPUB reader. EPUB spec includes ToC metadata. | MEDIUM | Parse EPUB ToC (NCX/nav). Display chapter list. Allow tap-to-jump. All competitors have this. |
| Dark mode / theme support | iOS users expect dark mode. Reading apps especially need it for nighttime use. Readly, Glance, Outread all offer themes. | LOW | Minimum: light + dark. SwiftUI supports system appearance natively. Add sepia as a bonus. |
| Font size adjustment | Accessibility fundamental. Every reading app has this. Users with vision needs will leave without it. | LOW | SwiftUI Dynamic Type support plus manual size controls. |
| Page reading mode (full-page text) | Not all reading sessions suit RSVP. Users need a traditional reading fallback. Voice Dream, Glance (overview mode) both offer this. | MEDIUM | Full-page text display with word-by-word highlight during TTS. This is the second reading mode described in PROJECT.md. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Synchronized TTS + RSVP | **Primary differentiator.** No iOS app combines RSVP word display with synchronized text-to-speech. Reedy (Android-only) is closest but not on iOS. Voice Dream highlights words with TTS but has no RSVP mode. RSVP apps (Outread, Glance) have no TTS. This is the gap. | HIGH | Requires coordinating AVSpeechSynthesizer callbacks (willSpeakRangeOfSpeechString) with RSVP word advancement. Voice drives the timing when TTS is on; timer drives it when TTS is off. The synchronization logic is the technical heart of the app. |
| Synchronized TTS + page-mode highlighting | Word-by-word highlighting in full-page view synced to TTS voice. Voice Dream does this. Speechify does this. But combining it with RSVP mode switching is novel. | HIGH | Uses same AVSpeechSynthesizer delegate callbacks. Highlight the current word in a scrolling text view. Must handle paragraph boundaries and page scrolling as speech advances. |
| Voice speed cap with graceful degradation | AVSpeechSynthesizer has a practical speed ceiling (~250-300 WPM depending on voice). Rather than producing garbled audio at high speeds, cap the voice and warn the user, or switch to RSVP-only mode. No competitor handles this gracefully. | MEDIUM | Detect synthesizer rate limits. When WPM exceeds voice capability: (a) cap voice speed and let RSVP run faster independently, or (b) disable voice and notify user. Better UX than competitors that just sound bad at high speeds. |
| Dual reading mode with seamless switching | Switch between RSVP and page mode mid-session without losing position. Glance has "overview mode" but it is a separate view, not a seamless toggle. | MEDIUM | Both modes share the same position model (chapter + word offset). Toggle button swaps the view while preserving exact position. |
| Curated Gutenberg collections | Built-in free book discovery without leaving the app. Gutenberg Reader apps exist but are standalone — no RSVP reader integrates Gutenberg directly. | MEDIUM | Curated lists (not full search for v1). Categories like "Classic Fiction," "Philosophy," "Science." Download EPUB from Gutenberg API. Avoids building full search infrastructure. |
| Multiple Apple voice selection with on-demand download | Let users pick from Apple's enhanced/premium voices and download voice packs on demand. Most TTS apps use their own AI voices (Speechify, ElevenReader). Using Apple's built-in voices means zero ongoing API cost. | MEDIUM | AVSpeechSynthesisVoice.speechVoices() lists available voices. Enhanced voices require download. Need UI to browse, preview, and trigger download. No subscription cost to user. |
| iCloud sync (library, positions, shelves) | Read on iPhone, continue on iPad. BookShelves and Voice Dream offer this. Important for multi-device Apple users but not day-one critical. | HIGH | SwiftData + CloudKit. Constraints: no unique attributes, all properties need defaults or optionals, all relationships optional. Sync conflicts possible with concurrent reading on multiple devices. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Deliberately NOT building these.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full Gutenberg search | Users want to find any book. Seems like obvious functionality. | Gutenberg has 70,000+ books. Building search, pagination, and browsing for that catalog is a large feature with ongoing maintenance. Dedicated Gutenberg apps already exist and do this well. Pulls focus from the core reading experience. | Curated lists for v1 organized by genre/popularity. Link out to gutenberg.org for full search. Add in-app search in v2 if validated. |
| Rich EPUB rendering (images, CSS, tables) | Users expect their EPUBs to look like they do in Apple Books. | Massive complexity. Full EPUB rendering is essentially building a web browser. Distracts from the core value (RSVP + TTS), and complex layouts break RSVP entirely since RSVP needs linear text. | Text-focused parsing only. Extract clean text + chapter structure. Inform users this is a speed-reading/listening app, not a layout-preserving reader. |
| AI voice cloning / celebrity voices | Speechify has Snoop Dogg, ElevenReader has classic celebrity voices. Flashy marketing feature. | Requires expensive API integration (ElevenLabs, etc.), ongoing per-use costs, licensing fees. Creates subscription pressure. Apple's built-in voices are free and increasingly good. | Use Apple's AVSpeechSynthesizer voices. Zero marginal cost. Improving with each iOS release. Frame as "no subscription required." |
| Social features (sharing, reviews, reading groups) | Some reading apps add social layers. Goodreads integration is commonly requested. | Massive scope expansion. Social features require backends, moderation, accounts. Completely orthogonal to the core value of focused reading. | None. Not part of the value proposition. Users have Goodreads/StoryGraph for social reading. |
| Android / web support | Broader market reach. Some users want cross-platform. | iOS-only scope is correct for v1. SwiftUI + SwiftData + AVSpeechSynthesizer are all Apple-only APIs. Cross-platform would mean rewriting everything. | Ship iOS first. Validate the concept. Consider cross-platform only after product-market fit. |
| Annotation and highlighting | Power readers want to mark up text. Standard in ebook readers like Voice Dream, BookFusion. | Annotations conflict with RSVP mode (can't highlight a single flashing word). In page mode they make sense but add significant UI complexity and data model weight for v1. | Bookmarks only for v1. Annotations can be a v1.x feature specifically for page mode. |
| Reading statistics / gamification | Track WPM improvement over time, streaks, goals. Outread and Spreeder include training features. | Gamification is scope creep for an MVP. The core question to validate is whether synchronized RSVP + TTS is valuable, not whether gamification drives retention. | Defer entirely. If users love the core experience, add stats in v2. |
| DRM-protected book support | Users want to read Kindle/iBooks purchases. Huge potential library. | DRM circumvention is legally problematic and technically complex. No legitimate path to supporting DRM books from other platforms. | Support DRM-free EPUB only. Be clear about this in marketing. Gutenberg books are all DRM-free. |

## Feature Dependencies

```
[EPUB Parser (text extraction + chapter structure)]
    |
    +--requires--> [Library View (display imported books)]
    |                  |
    |                  +--requires--> [Shelves / Organization]
    |                  +--requires--> ["Continue Reading" / Last Read]
    |
    +--requires--> [Table of Contents Navigation]
    |
    +--requires--> [RSVP Reading Mode]
    |                  |
    |                  +--requires--> [WPM Speed Controls]
    |                  +--enhances--> [TTS Synchronization]
    |                                     |
    |                                     +--requires--> [AVSpeechSynthesizer Integration]
    |                                     +--requires--> [Voice Selection + Download]
    |                                     +--requires--> [Voice Speed Cap Logic]
    |
    +--requires--> [Page Reading Mode]
    |                  |
    |                  +--enhances--> [TTS with Word Highlighting]
    |                                     |
    |                                     +--requires--> [AVSpeechSynthesizer Integration]
    |
    +--requires--> [Reading Position Persistence]
                       |
                       +--enhances--> [iCloud Sync]

[Gutenberg Integration]
    +--requires--> [Network Layer (download EPUBs)]
    +--requires--> [EPUB Parser]
    +--requires--> [Library View]

[Dual Mode Switching]
    +--requires--> [RSVP Reading Mode]
    +--requires--> [Page Reading Mode]
    +--requires--> [Shared Position Model]
```

### Dependency Notes

- **EPUB Parser is the foundation:** Everything depends on getting clean text out of EPUB files with chapter structure intact. This must be built first and built well.
- **AVSpeechSynthesizer Integration is shared:** Both RSVP-sync and page-mode highlighting use the same synthesizer delegate callbacks. Build this as a single service consumed by both reading modes.
- **Position model must be mode-agnostic:** If RSVP and page mode use different position representations, seamless switching breaks. Use a unified model (chapter index + word offset).
- **iCloud Sync enhances position persistence:** Sync builds on local persistence. Get local storage right first, then layer CloudKit on top.
- **Gutenberg Integration is independent of reading modes:** It feeds into the library but has no dependency on RSVP or TTS. Can be built in parallel.

## MVP Definition

### Launch With (v1)

Minimum viable product — what is needed to validate that synchronized RSVP + TTS is valuable.

- [ ] EPUB import (Files app integration) — users need content to read
- [ ] EPUB text parser with chapter structure — foundation for everything
- [ ] Basic library view with book covers/titles — users need to find their books
- [ ] RSVP reading mode with adjustable WPM (100-500) — core reading experience
- [ ] Page reading mode with word highlighting — alternative reading experience
- [ ] AVSpeechSynthesizer TTS with word-level sync — the primary differentiator
- [ ] Voice selection (Apple built-in voices) — users need voice choice
- [ ] Voice speed cap with graceful handling — prevents broken audio experience
- [ ] Reading position persistence (per-book) — users must not lose their place
- [ ] Table of contents navigation — users need to jump between chapters
- [ ] Bookmarks — users need to mark spots
- [ ] Dark mode + light mode — baseline accessibility
- [ ] Offline reading (books + downloaded voice packs) — must work without internet

### Add After Validation (v1.x)

Features to add once core is working and users confirm the RSVP + TTS concept has value.

- [ ] Curated Gutenberg collections — when users want more free content beyond their own EPUBs
- [ ] Shelves / custom organization — when library size grows beyond a flat list
- [ ] "Continue reading" / last read section — when users have 5+ books and need quick access
- [ ] iCloud sync across devices — when users request multi-device support
- [ ] Additional theme options (sepia, custom colors) — low-effort polish
- [ ] Font selection — when accessibility feedback arrives
- [ ] On-demand enhanced voice pack download — when users want better voice quality

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] In-app Gutenberg search — only if curated lists prove insufficient
- [ ] Reading statistics (WPM tracking over time) — only if users ask for progress tracking
- [ ] Annotations in page mode — only if users want to mark up text
- [ ] Share reading position / book recommendations — only with clear user demand
- [ ] iPad-optimized layouts (split view, larger typography controls) — after iPhone experience is solid

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| EPUB parser + import | HIGH | MEDIUM | P1 |
| RSVP reading mode | HIGH | MEDIUM | P1 |
| TTS synchronization (RSVP + page mode) | HIGH | HIGH | P1 |
| Page reading mode + word highlight | HIGH | MEDIUM | P1 |
| WPM speed controls | HIGH | LOW | P1 |
| Reading position persistence | HIGH | LOW | P1 |
| Library view | HIGH | MEDIUM | P1 |
| Table of contents navigation | MEDIUM | MEDIUM | P1 |
| Voice selection | MEDIUM | LOW | P1 |
| Voice speed cap logic | MEDIUM | MEDIUM | P1 |
| Bookmarks | MEDIUM | LOW | P1 |
| Dark mode | MEDIUM | LOW | P1 |
| Offline support | HIGH | LOW | P1 |
| Curated Gutenberg integration | MEDIUM | MEDIUM | P2 |
| Shelves / organization | MEDIUM | MEDIUM | P2 |
| "Continue reading" section | MEDIUM | LOW | P2 |
| iCloud sync | MEDIUM | HIGH | P2 |
| Font selection | LOW | LOW | P2 |
| Enhanced voice downloads | LOW | MEDIUM | P2 |
| Gutenberg search | LOW | HIGH | P3 |
| Reading statistics | LOW | MEDIUM | P3 |
| Annotations | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Outread | Glance | Voice Dream | Speechify | RSVP Reader | Our Approach |
|---------|---------|--------|-------------|-----------|-------------|--------------|
| RSVP mode | Yes | Yes | No | No | Yes | Yes |
| Page reading | Guide highlight | Overview mode | Yes (primary) | Yes (primary) | Cruise mode | Yes, with word highlight |
| TTS | No | No | Yes (primary) | Yes (primary) | No | Yes, synced to both modes |
| RSVP + TTS sync | No | No | No | No | No | **Yes (core differentiator)** |
| Word-level highlight | No (chunk) | No | Yes (with TTS) | Yes (with TTS) | ORP highlight | Yes (both modes) |
| EPUB support | Yes | Yes | Yes | Limited | Yes | Yes |
| Gutenberg | No | No | No | No | No | Yes (curated) |
| Offline | Yes | Yes | Yes | Partial | Yes | Yes |
| iCloud sync | Account-based | No | Yes (iCloud) | Account-based | No | Yes (SwiftData+CloudKit) |
| Voice selection | N/A | N/A | Multiple | 200+ AI | N/A | Apple built-in voices |
| Pricing | Subscription | Free (no ads) | Subscription | Subscription | Free + IAP | TBD |
| Accessibility | Dyslexia support | Minimal | Strong (award) | Strong | OpenDyslexic font | Dynamic Type + VoiceOver |

### Key Competitive Insight

The market splits into two camps that do not overlap on iOS:
1. **RSVP speed readers** (Outread, Glance, RSVP Reader): Visual speed reading, no audio
2. **TTS readers** (Voice Dream, Speechify, ElevenReader): Audio-first, word highlighting, no RSVP

Blaze Books sits at the intersection. The only app that has attempted combining both is Reedy, which is Android/Chrome only and does not offer tight synchronization between the two. This is a genuine gap in the iOS market.

## Sources

- [Outread - Speed Reading App](https://outreadapp.com/) — RSVP + guide highlighting, no TTS
- [Glance - EPUB Speed Reader (App Store)](https://apps.apple.com/us/app/glance-epub-speed-reader/id6747596694) — RSVP, no TTS, free/no ads
- [RSVP Reader (App Store)](https://apps.apple.com/us/app/rsvp-reader-speed-reading/id6757968737) — RSVP with ORP, no TTS
- [Voice Dream Reader](https://www.voicedream.com/reader/) — TTS with word highlighting, no RSVP
- [Speechify](https://speechify.com/) — TTS with word sync, AI voices, subscription model
- [ElevenReader](https://elevenreader.io) — AI TTS, EPUB support, text highlighting
- [Reedy](https://reedy-reader.com/) — Android-only, RSVP + TTS but not iOS
- [Rapid Reader](https://www.rapidreaderapp.com/) — RSVP for iPhone, training focus
- [Readly (App Store)](https://apps.apple.com/us/app/readly-epub-speed-reading/id6755335073) — RSVP, bookmarks, offline
- [BookShelves](https://getbookshelves.app/) — iCloud sync library management
- [BookFusion](https://www.bookfusion.com/) — Cross-platform library with shelves
- [Gutenberg Reader + Many Books (App Store)](https://apps.apple.com/us/app/gutenberg-reader-many-books/id1294103623) — Gutenberg integration
- [Speed Reading Lounge - 20 Best Speed Reading Apps](https://www.speedreadinglounge.com/speed-reading-apps) — Competitive overview
- [AVSpeechSynthesizer - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) — TTS API reference
- [Hacking with Swift - AVSpeechSynthesizer word highlighting](https://www.hackingwithswift.com/example-code/media/how-to-highlight-text-to-speech-words-being-read-using-avspeechsynthesizer) — willSpeakRangeOfSpeechString callback

---
*Feature research for: iOS RSVP ebook reader with synchronized TTS*
*Researched: 2026-02-20*
