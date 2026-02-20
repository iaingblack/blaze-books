# Pitfalls Research

**Domain:** iOS RSVP ebook reader with synchronized TTS (Blaze Books)
**Researched:** 2026-02-20
**Confidence:** HIGH (verified across Apple Developer Forums, official docs, Context7, multiple community sources)

## Critical Pitfalls

### Pitfall 1: AVSpeechSynthesizer Silently Stops Speaking Long Text

**What goes wrong:**
AVSpeechSynthesizer stops speaking partway through long utterances (confirmed on iOS 17+). A 1200-word string may only produce 300 words of speech before the `didCancelUtterance` delegate fires. The bug is voice-specific and string-specific -- certain voices like "Daniel Enhanced" trigger premature completion callbacks while others work fine with the same text. Apple has acknowledged the issue with "no workaround" as their official response.

**Why it happens:**
An internal buffer or processing limit inside AVSpeechSynthesizer causes it to cancel long utterances. The root cause is within Apple's framework and varies by iOS version, selected voice, and text content. The `.rate` property on AVSpeechUtterance is also reported as sometimes not being applied, compounding synchronization issues.

**How to avoid:**
- Never pass an entire chapter as a single AVSpeechUtterance. Break text into sentence-level or paragraph-level utterances and queue them sequentially.
- Implement a delegate-driven pipeline: when `didFinishSpeechUtterance` fires, enqueue the next chunk. This also gives natural pause points for user interaction.
- Store the AVSpeechSynthesizer as an instance property (not a local variable) -- if it goes out of scope, speech stops immediately with no error.
- Periodically recreate the synthesizer instance after a configurable number of utterances to avoid accumulated state bugs.
- Test every supported voice with long texts during development. Voice behavior varies dramatically.

**Warning signs:**
- Speech stops mid-sentence without user action
- `didCancelUtterance` fires when you did not call `stopSpeaking`
- Users report "it only reads the first page" or "it stops randomly"
- Works in simulator but fails on device (or vice versa)

**Phase to address:**
Phase 1 (core TTS integration). The utterance-chunking architecture must be the foundation, not a retrofit.

---

### Pitfall 2: Word-Voice Synchronization Drift

**What goes wrong:**
The `willSpeakRange(of:utterance:)` delegate callback reports incorrect character ranges under certain conditions. The returned NSRange accumulates an offset error that grows over the utterance, causing the highlighted word on screen to diverge from what the voice is actually speaking. This is a known Apple bug that has persisted across multiple iOS versions.

**Why it happens:**
AVSpeechSynthesizer's internal text processing does not always match the character indices of the original string. Unicode characters, punctuation, and certain voice engines cause the range calculation to drift. The callback fires "just before" a word is spoken, but the timing granularity is not guaranteed -- it can lag behind actual audio output.

**How to avoid:**
- Use sentence-level utterances so that any drift resets at sentence boundaries. Shorter utterances = less accumulated error.
- Implement a word-index tracking system independent of the delegate callback. Maintain your own word array with pre-computed ranges. Use the delegate callback as a "hint" and snap to the nearest word in your own array.
- Add a tolerance window: if the delegate-reported range is within N characters of an expected word boundary, snap to that word.
- For RSVP mode, drive word advancement from your own timer, not from the TTS callback. Use the TTS callback only to verify sync and correct drift.
- Build a "sync checkpoint" system: at known boundaries (sentence starts, paragraph starts), force-align the visual position and speech position.

**Warning signs:**
- Highlighted word is 1-3 words behind or ahead of spoken word
- Sync error grows over time within a chapter but resets at chapter boundaries
- Different voices produce different amounts of drift
- Works perfectly with short test strings but drifts with real book content

**Phase to address:**
Phase 1-2 (reading modes). Must be designed into the synchronization architecture from the start. The dual-source tracking (timer-driven RSVP + delegate-driven page mode) requires different sync strategies.

---

### Pitfall 3: CloudKit Schema Is Additive-Only in Production

**What goes wrong:**
Once you deploy your SwiftData/CloudKit schema to the production CloudKit environment, you cannot delete entities, remove attributes, or change attribute types. You can only add new fields. If your initial data model is wrong, you are stuck with those fields forever in production. Developers discover this after their first App Store release and face permanent schema debt.

**Why it happens:**
CloudKit's production schema is designed for backward compatibility across app versions. Users on older app versions must still be able to sync. This constraint is fundamental to CloudKit's architecture, not a bug. Developers accustomed to local database migrations (where you can do anything) do not internalize this restriction until it is too late.

**How to avoid:**
- Use VersionedSchema from day one, even for your initial release. Ship v1 with a VersionedSchema so you have a stable migration baseline.
- Design your data model conservatively: make fields optional or provide defaults. Assume you will need to add fields later but can never remove them.
- Do not deploy to CloudKit production until your model is thoroughly validated. Use the development environment extensively.
- Avoid unique constraints entirely -- CloudKit does not support them and they will cause sync failures.
- All relationships must be optional. This is a hard requirement, not a suggestion.
- Test with the production CloudKit environment before App Store submission (swap to production in entitlements, run against production container).

**Warning signs:**
- You are changing your model frequently during development without version tracking
- You have non-optional properties or relationships in your SwiftData models
- You have not tested against the production CloudKit environment before your first TestFlight
- You used `@Attribute(.unique)` on any property

**Phase to address:**
Phase 1 (data model design). The model must be CloudKit-compatible from initial design. Retrofitting CloudKit compatibility onto an existing schema is painful and sometimes impossible.

---

### Pitfall 4: SwiftData + CloudKit Sync Fails Silently in Release Builds

**What goes wrong:**
CloudKit sync works perfectly in Xcode debug builds but fails completely in TestFlight and App Store builds. No error is shown. Data simply does not sync. Users see different data on different devices with no indication of a problem.

**Why it happens:**
Multiple interacting causes:
1. CloudKit has separate development and production environments. Debug builds use development; TestFlight/App Store uses production. If you never deployed your schema to the production environment via the CloudKit Dashboard, sync has no schema to work with.
2. On macOS (if you ever support it), forgetting to link `CloudKit.framework` causes silent sync failure in release builds -- the app compiles fine without it.
3. The `initializeCloudKitSchema()` call that generates the schema must be run in development, not production.

**How to avoid:**
- Before your first TestFlight build: open CloudKit Dashboard, navigate to your container, and click "Deploy Schema Changes" to push to production.
- Add a development-only startup check that calls `initializeCloudKitSchema()` on your `NSPersistentCloudKitContainer` (the underlying Core Data container that SwiftData uses).
- Test iCloud sync specifically in TestFlight before App Store submission. Debug sync success does not predict production sync success.
- Verify your entitlements file specifies the correct CloudKit container identifier.
- Build a simple "sync status" debug view that shows last sync timestamp, pending changes count, and any errors from the CloudKit notification handlers.

**Warning signs:**
- Sync works on simulator/debug device but not TestFlight
- No sync errors in console but data does not appear on second device
- Works after clean install but existing users report missing data after update

**Phase to address:**
Phase 3 (iCloud sync). Must be verified end-to-end in production CloudKit before any public release.

---

### Pitfall 5: EPUB Parsing Fails on Real-World Files

**What goes wrong:**
EPUB files from Project Gutenberg and user-imported files contain malformed XML, undeclared HTML entities (like `&nbsp;`), missing file references in manifests, XML 1.1 declarations, inconsistent encoding, and nested elements that break strict parsers. An EPUB parser that works on clean test files fails on a significant percentage of real-world EPUBs.

**Why it happens:**
The EPUB specification is based on XHTML, which only defines five entities (`&amp;`, `&lt;`, `&gt;`, `&apos;`, `&quot;`). But many EPUBs use HTML entities like `&nbsp;`, `&mdash;`, `&rsquo;` which are technically illegal in XHTML. Tools that generate EPUBs (including older versions of Calibre, Sigil, and various publisher toolchains) produce non-conformant files. Project Gutenberg EPUBs specifically have known quirks with encoding and entity usage.

**How to avoid:**
- Use a lenient XML parser or pre-process XHTML content to replace common HTML entities before parsing.
- Build an entity resolution layer that maps all HTML5 named entities to their Unicode equivalents.
- Handle missing manifest entries gracefully -- log a warning but do not crash.
- Test with at least 50 real EPUBs from Project Gutenberg across different eras and languages. Edge cases appear in roughly 10-20% of files.
- Implement a fallback text extraction pipeline: if structured parsing fails, fall back to stripping all tags and extracting raw text with basic chapter detection via heading tags.
- Guard against XXE (XML External Entity) attacks by disabling external entity resolution in your XML parser configuration.

**Warning signs:**
- Parser crashes or returns empty content for specific books
- Special characters render as `?` or garbage
- Chapter detection misses chapters or creates spurious chapter breaks
- Books from certain publishers consistently fail

**Phase to address:**
Phase 1 (EPUB import and parsing). The parser must be battle-tested against diverse real-world files before any reading functionality is built on top of it.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Passing entire chapters as single AVSpeechUtterance | Simpler code, fewer delegate callbacks | Speech truncation bugs, sync drift, no pause granularity | Never -- sentence-level chunking is required |
| Skipping VersionedSchema for v1 | Faster initial development | Cannot safely migrate when you add features; risk of data loss on update | Never -- trivial to add upfront, painful to retrofit |
| Using `Timer` instead of `CADisplayLink`/GCD for RSVP | Familiar API, simple setup | Timer drift at high WPM, inconsistent word display timing, jank at 400+ WPM | Only for prototyping; replace before any user testing |
| Hardcoding voice availability instead of checking at runtime | Simpler voice selection UI | Crash or silent failure when expected voice is not downloaded; varies by device/region | Never -- voice availability varies per device |
| Loading entire EPUB into memory at once | Simpler architecture | Memory pressure kills on large books (100MB+ EPUBs exist); iOS terminates the process | Only for books under 5MB; must stream for larger files |
| Not implementing `Sendable` conformance on model types | Avoids Swift concurrency complexity | Threading violations when CloudKit sync (which runs on background threads) touches model objects, causing crashes | Never once CloudKit sync is enabled |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| AVSpeechSynthesizer + Audio Session | Not configuring AVAudioSession category; speech output silenced by ringer switch or other audio apps | Set `.playback` category with `.duckOthers` option; set `usesApplicationAudioSession = true`; handle interruption notifications |
| CloudKit + SwiftData | Assuming all SwiftData features work with CloudKit (unique constraints, deny delete rules, non-optional relationships) | Audit model against CloudKit constraints before writing any code; all relationships optional, no unique constraints, no deny delete rules |
| Project Gutenberg API | Treating the catalog as a stable API; scraping HTML pages | Use the Gutendex JSON API (`gutendex.com/books`) or download catalog data in bulk; URLs and formats change |
| AVSpeechSynthesizer + Background Audio | Enabling "Audio, AirPlay, and Picture in Picture" background mode and assuming TTS continues in background | TTS stops when app backgrounds even with background audio mode. Workaround: play a silent AVAudioPlayer track alongside TTS to keep audio session active |
| SwiftData + SwiftUI observation | Expecting `@Query` to automatically update when CloudKit sync delivers remote changes | CloudKit sync updates happen on a background context; `@Query` may not refresh. Use `NSPersistentCloudKitContainer`'s notification (`NSPersistentStoreRemoteChange`) to trigger context refresh |
| Voice pack downloads | Trying to programmatically trigger voice downloads | Voice downloads cannot be initiated from your app. Must direct users to Settings > Accessibility > Spoken Content > Voices. Listen for `AVSpeechSynthesizer.availableVoicesDidChangeNotification` to detect when new voices become available |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading full EPUB ZIP into memory | App killed by iOS memory pressure system (no crash log, just termination) | Unzip to temp directory, load chapters on demand, release chapter data when scrolling away | Books over 20-50MB (EPUBs with embedded images) |
| Creating new AVSpeechSynthesizer per utterance | Increasing latency between words, memory growth, eventual speech failure | Reuse a single synthesizer instance; only recreate periodically to reset state | After ~100 utterances with create/destroy pattern |
| SwiftData `@Query` with complex predicates on large libraries | UI freezes during library scrolling; main thread blocked by fetch | Use `fetchLimit`, implement pagination, move complex queries to background with `ModelActor` | Libraries over 200-500 books |
| Rendering full chapter HTML in WKWebView for page mode | Slow chapter loads, high memory, scroll position jumps | For text-focused reader, parse to attributed strings or plain text; avoid WebView entirely | Chapters over 10,000 words |
| RSVP timer firing on main thread with UI updates | Dropped frames, inconsistent word timing, visible stutter | Use `CADisplayLink` for display-synchronized updates; compute word advancement in the callback based on elapsed time, not fixed intervals | WPM above 300 (each word displays for less than 200ms) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Not disabling XML external entity resolution in EPUB parser | XXE injection -- malicious EPUB could read local files or make network requests | Configure XML parser with `shouldResolveExternalEntities = false`; use `XMLParser` defaults which are safe, but verify if using third-party parsers |
| Storing user's reading positions in unencrypted iCloud key-value store | Reading habits are sensitive data; could be exposed in iCloud breach | Use SwiftData + CloudKit (encrypted at rest by Apple) rather than `NSUbiquitousKeyValueStore` for position data |
| Not validating EPUB content before rendering in WebView | JavaScript injection via malicious EPUB content (if using WKWebView for rendering) | Sanitize HTML content; disable JavaScript in WKWebView configuration if used; prefer attributed string rendering over WebView |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No graceful voice speed cap | At high WPM (400+), AVSpeechSynthesizer produces garbled, unintelligible speech | Detect the practical voice speed ceiling (~250-300 WPM for most voices); show a clear indicator when WPM exceeds voice capability; offer to continue RSVP without voice or slow voice to its max |
| Assuming voices are available | App shows voice options that are not downloaded; selecting one produces silence | Query `AVSpeechSynthesisVoice.speechVoices()` at runtime; show download status; provide a "Go to Settings" deep link for voice installation; gracefully fall back to compact/default voice |
| No reading position feedback in RSVP mode | Users feel lost -- "where am I in the book?" | Show progress bar, chapter name, percentage, and estimated time remaining even in RSVP mode |
| Jarring transition between RSVP and page mode | Users switch modes and lose their place, or the word they were on is not visible | When switching from RSVP to page mode, scroll to and highlight the exact word; when switching back, start RSVP from that word |
| No pause-on-long-words in RSVP | Long words flash by at the same speed as short ones; comprehension drops | Implement variable timing: scale display duration by word length and punctuation (longer pause after periods, commas) |
| Empty library on first launch | App looks broken or incomplete; triggers App Store Guideline 4.2 (minimum functionality) rejection | Ship with 5-10 pre-loaded Project Gutenberg books or show a compelling onboarding flow that immediately gets content into the library |

## "Looks Done But Isn't" Checklist

- [ ] **TTS integration:** Often missing audio session interruption handling (phone calls, Siri, other apps) -- verify speech resumes correctly after interruption and position is not lost
- [ ] **iCloud sync:** Often missing production schema deployment -- verify sync works in TestFlight, not just debug builds
- [ ] **EPUB parser:** Often missing entity resolution for HTML named entities -- verify books with accented characters, em-dashes, and smart quotes parse correctly
- [ ] **RSVP timer:** Often missing variable word timing -- verify long words and punctuation get proportionally more display time
- [ ] **Background audio:** Often missing re-activation after interruption -- verify TTS resumes when returning from a phone call or Siri interaction
- [ ] **Voice selection:** Often missing handling for deleted/unavailable voices -- verify the app does not crash or go silent if a previously selected voice is no longer on device
- [ ] **Book import:** Often missing validation of malformed EPUBs -- verify import of 20+ real Project Gutenberg books of varying age and language
- [ ] **CloudKit model:** Often missing relationship inverse declarations -- verify bidirectional relationships are explicitly defined, not relying on SwiftData inference
- [ ] **Reading position save:** Often missing debounced saves -- verify position is saved on app background, not just on explicit chapter completion
- [ ] **Offline mode:** Often missing state for "voice not downloaded" -- verify the app handles being offline with an undownloaded voice gracefully (offer RSVP-only or page-only mode)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CloudKit schema shipped with wrong model | HIGH | Cannot delete fields in production. Add new correctly-named fields, migrate data in app update, deprecate old fields (they remain in schema forever). May need to create a new CloudKit container for clean start (loses all user data). |
| AVSpeechSynthesizer truncation bugs | MEDIUM | Retrofit sentence-level chunking. Requires reworking the utterance queue and sync tracking. Roughly 2-3 days of work if the architecture was not designed for it. |
| EPUB parser crashes on real-world files | MEDIUM | Add entity pre-processing layer and lenient parsing fallbacks. Can be done incrementally per-bug-report but each fix risks introducing new edge cases. Budget 1-2 days per class of malformed EPUB. |
| RSVP timing drift at high WPM | LOW | Replace `Timer` with `CADisplayLink` and compute word index from elapsed time. Straightforward refactor, ~1 day. |
| Sync works in dev but not production | LOW | Deploy schema to production CloudKit, rebuild TestFlight. 1-2 hours once you know the cause, but can waste days diagnosing if you do not know to check this. |
| Memory pressure kills on large books | MEDIUM | Implement lazy chapter loading and release. Requires reworking the book data pipeline to stream rather than load-all. 2-4 days depending on parser architecture. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| AVSpeechSynthesizer truncation | Phase 1: TTS foundation | Test with 5000+ word chapters using every supported voice; verify no `didCancelUtterance` fires unexpectedly |
| Word-voice sync drift | Phase 2: Reading modes | Play a full chapter in both RSVP and page mode; visually confirm highlighted word matches spoken word at start, middle, and end |
| CloudKit schema lock-in | Phase 1: Data model design | Review model against CloudKit constraints checklist before writing any sync code; all properties optional or defaulted, all relationships optional, no unique constraints |
| Silent sync failure in production | Phase 3: iCloud sync | Verify sync round-trip in TestFlight between two real devices before any public release |
| EPUB parsing failures | Phase 1: EPUB import | Run parser against 50+ Project Gutenberg EPUBs; track success rate; target 95%+ |
| Memory pressure on large books | Phase 1: EPUB import | Profile memory with a 100MB EPUB; verify peak memory stays under 100MB; test with simulated memory pressure |
| Background TTS interruption | Phase 2: Audio integration | Test: start TTS, background app, receive phone call, decline call, foreground app -- verify speech resumes at correct position |
| RSVP timing accuracy | Phase 2: RSVP mode | Measure actual WPM at 100, 300, and 500 WPM settings using a stopwatch over 100 words; verify within 5% of target |
| App Store rejection (4.2/empty state) | Phase 4: Polish/submission | Ensure first-launch experience shows content or compelling onboarding; include all required privacy descriptions for microphone (if used), speech recognition, and iCloud |
| Voice availability assumptions | Phase 2: Voice selection | Test on a fresh device with no enhanced voices downloaded; verify app does not crash and provides clear guidance |

## Sources

- [AVSpeechSynthesizer broken on iOS 17 -- Apple Developer Forums](https://developer.apple.com/forums/thread/737685)
- [AVSpeechSynthesizer broken on iOS 17 in Xcode 15 -- Apple Developer Forums](https://developer.apple.com/forums/thread/738048)
- [AVSpeechSynthesizer willSpeakRange delegate issues -- Apple Developer Forums](https://developer.apple.com/forums/thread/80803)
- [AVSpeechSynthesizer not working in background -- Apple Developer Forums](https://developer.apple.com/forums/thread/23160)
- [AVSpeechSynthesizer in background -- Apple Developer Forums](https://developer.apple.com/forums/thread/27097)
- [Syncing model data across a person's devices -- Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) (HIGH confidence -- Context7 verified)
- [3 Things I Wish I Knew Before Starting With SwiftData + CloudKit -- Medium](https://carolanelefebvre.medium.com/en-3-things-i-wish-i-knew-before-starting-with-swiftdata-cloudkit-bb53df9bb6b1)
- [Designing Models for CloudKit Sync -- fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [Fix Core Data/SwiftData Cloud Sync Issues in Production -- fatbobman](https://fatbobman.com/en/snippet/why-core-data-or-swiftdata-cloud-sync-stops-working-after-app-store-login/)
- [Handling Malformed EPUB files -- EpubReader](https://os.vers.one/EpubReader/malformed-epub/index.html)
- [EPUB entities discussion -- MobileRead Forums](https://www.mobileread.com/forums/showthread.php?t=199342)
- [App Store Review Guidelines -- Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Guideline 4.2 Minimum Functionality -- iOS Submission Guide](https://iossubmissionguide.com/guideline-4-2-minimum-functionality/)
- [An Unauthorized Guide to SwiftData Migrations -- Atomic Robot](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [If You Are Not Versioning Your SwiftData Schema -- AzamSharp](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html)
- [Timer vs CADisplayLink -- Hacking with Swift](https://www.hackingwithswift.com/articles/117/the-ultimate-guide-to-timer)
- [RSVP speed reading apps comparison -- Speed Reading Lounge](https://www.speedreadinglounge.com/speed-reading-apps)
- [Create a seamless speech experience -- WWDC20](https://developer.apple.com/videos/play/wwdc2020/10022/)

---
*Pitfalls research for: iOS RSVP ebook reader with synchronized TTS (Blaze Books)*
*Researched: 2026-02-20*
