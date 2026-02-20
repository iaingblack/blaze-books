---
phase: 02-reading-engine
verified: 2026-02-20T21:00:00Z
status: passed
score: 10/10 must-haves verified
gaps: []
human_verification:
  - test: "RSVP word display with ORP alignment"
    expected: "Each word appears one at a time with ORP character highlighted in accent color, anchored to exact screen center via GeometryReader-computed frame widths"
    why_human: "Visual alignment correctness and readability at speed cannot be verified programmatically"
  - test: "TTS synchronization -- speech tracks displayed word"
    expected: "The RSVP display word changes in sync with spoken audio; no perceptible drift between audio and visual"
    why_human: "Real-time synchronization quality requires runtime observation"
  - test: "Voice speed cap slider snap behavior"
    expected: "With TTS on and WPM above voice cap, slider snaps to capped value and SpeedCapBanner appears with correct message"
    why_human: "Requires runtime TTS playback to trigger speed capping; note: cap only triggers when TTS is on AND a voice is selected AND requestedWPM > voice cap (currently selectedVoiceIdentifier may be nil at first use)"
---

# Phase 2: Reading Engine Verification Report

**Phase Goal:** The synchronization engine keeps TTS audio locked to visual word display, with voice selection and graceful speed capping
**Verified:** 2026-02-20T21:00:00Z
**Status:** PASSED
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | RSVPEngine advances through chapter words at configured WPM with punctuation-aware pauses | VERIFIED | `RSVPEngine.swift` uses Timer with `displayDuration(for:)` applying 0.9x/2.0x/3.0x multipliers and length penalty; `loadChapter` calls `WordTokenizer` and maps tokens to `ORPWord` |
| 2 | TTSService speaks chapter sentence-by-sentence with global word-boundary callbacks | VERIFIED | `TTSService.swift` uses `NLTokenizer(unit: .sentence)` to build `sentenceQueue`, `DelegateHandler.willSpeakRangeOfSpeechString` converts char range to global word index via cumulative offsets |
| 3 | ORP position is calculated for every word using the lookup table algorithm | VERIFIED | `ORPWord.orpPosition(forWordLength:)` implements the speedread table: 1-2->0, 3-6->1, 7-10->2, 11-13->3, 14+->4; applied in `ORPWord.from(token:)` |
| 4 | ReadingCoordinator orchestrates RSVP and TTS in dual-mode: TTS drives word advancement when on, Timer drives it when off | VERIFIED | `ReadingCoordinator.play()` branches on `isTTSEnabled`; `handleTTSWordBoundary` updates `currentWord` from TTSService callbacks; `startRSVPObservation()` uses `withObservationTracking` recursive pattern in Timer mode |
| 5 | Per-voice speed cap is detected and WPM is clamped to the voice's natural maximum | VERIFIED | `SpeedCapService.effectiveWPM(requested:forVoice:)` returns `min(requested, maxWPM)`; `ReadingCoordinator.applySpeedCap()` sets `isSpeedCapped` and `speedCapMessage`; `setWPM` applies cap before passing to engines |
| 6 | VoiceManager enumerates installed English voices with quality tiers | VERIFIED | `VoiceManager.loadVoices()` calls `AVSpeechSynthesisVoice.speechVoices()`, filters `language.hasPrefix("en")`, excludes novelty voices, maps to `VoiceInfo` sorted by quality tier |
| 7 | User returning from Settings triggers voice list refresh | VERIFIED | `VoiceManager.startObservingVoiceChanges()` registers for `AVSpeechSynthesizer.availableVoicesDidChangeNotification`; calls `loadVoices()` on notification |
| 8 | User can see words displayed one at a time with ORP letter highlighted in accent color at screen center | VERIFIED | `RSVPDisplayView` uses `GeometryReader`, three-segment HStack with `halfWidth - halfChar` frames; ORP character uses `.foregroundStyle(Color.accentColor)` with `.fontWeight(.bold)` |
| 9 | User can select a voice from in-reader voice picker and hear a preview | VERIFIED | `VoicePickerView` lists `voiceManager.installedVoices`; speaker icon calls `voiceManager.previewVoice(voice)`; row tap calls `voiceManager.selectVoice(voice)` and `onVoiceSelected` closure |
| 10 | User sees inline banner when WPM exceeds voice capability; user can tap Open Settings | VERIFIED | `SpeedCapBanner` receives `coordinator.speedCapMessage` and `coordinator.isSpeedCapped` from `ReadingView`; `VoicePickerView` has "Open Voice Settings" button calling `voiceManager.openVoiceSettings()` |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BlazeBooks/Models/ORPWord.swift` | Word model with ORP index, text segments, sentence-end flag | VERIFIED | `struct ORPWord` with `text`, `orpIndex`, `beforeORP`, `orpCharacter`, `afterORP`, `isSentenceEnd`, `wordIndex`; static factory `from(token:)` |
| `BlazeBooks/Models/VoiceInfo.swift` | Voice metadata with identifier, name, quality, installed status | VERIFIED | `struct VoiceInfo: Identifiable` with `Quality` enum (default/enhanced/premium), `Comparable` ordering, static factory `from(voice:)` |
| `BlazeBooks/Engines/RSVPEngine.swift` | Timer-driven word advancement with ORP calculation and punctuation pauses | VERIFIED | `@Observable final class RSVPEngine`; `loadChapter`, `play`, `pause`, `resume`, `setWPM`, `seekTo`, `word(at:)`, `onChapterComplete` closure |
| `BlazeBooks/Engines/TTSService.swift` | AVSpeechSynthesizer wrapper with sentence chunking and word-boundary tracking | VERIFIED | `@Observable final class TTSService`; inner `DelegateHandler: NSObject, AVSpeechSynthesizerDelegate`; `sentenceQueue`, `onWordBoundary`, `onChapterComplete` |
| `BlazeBooks/Engines/ReadingCoordinator.swift` | Orchestrator binding RSVPEngine and TTSService with mode switching and chapter auto-advance | VERIFIED | `@Observable final class ReadingCoordinator`; dual-mode play/pause/resume/stop; `withObservationTracking` bridge; 1.5s chapter auto-advance via `Task.sleep` |
| `BlazeBooks/Services/SpeedCapService.swift` | Per-voice WPM calibration with graceful capping | VERIFIED | `@Observable final class SpeedCapService`; `maxWPM(forVoice:)` with quality-tier defaults (300/350/400); `wpmToRate` linear interpolation; `voiceCapCache` |
| `BlazeBooks/Services/VoiceManager.swift` | Voice enumeration, filtering, download guidance, and notification observation | VERIFIED | `@Observable final class VoiceManager`; English filter; novelty voice exclusion; `previewVoice`, `openVoiceSettings`, `startObservingVoiceChanges` |
| `BlazeBooks/Views/Reading/RSVPDisplayView.swift` | ORP-aligned single word display with highlighted recognition point | VERIFIED | `struct RSVPDisplayView`; `GeometryReader` centering; `.transaction { $0.animation = nil }` for instant swap; vertical guide line; `.foregroundStyle(.white)` on dark background |
| `BlazeBooks/Views/Reading/VoicePickerView.swift` | In-reader voice selection sheet with installed voices and download guidance | VERIFIED | `struct VoicePickerView`; Installed + Available for Download sections; checkmark, preview button, "Open Voice Settings" |
| `BlazeBooks/Views/Reading/SpeedCapBanner.swift` | Inline non-disruptive banner showing voice speed cap message | VERIFIED | `struct SpeedCapBanner`; orange info icon; `.transition(.move(edge: .top).combined(with: .opacity))`; conditionally visible |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `RSVPEngine.swift` | `WordTokenizer.swift` | `tokenizer.tokenize(text)` in `loadChapter` | WIRED | Line 57: `let tokens = tokenizer.tokenize(text)` with `@ObservationIgnored private let tokenizer = WordTokenizer()` |
| `RSVPEngine.swift` | `ORPWord.swift` | `ORPWord.from(token:)` in `loadChapter` | WIRED | Line 58: `words = tokens.map { ORPWord.from(token: $0) }` |
| `TTSService.swift` | `NLTokenizer` (sentence) | `NLTokenizer(unit: .sentence)` in `prepareChapter` | WIRED | Line 72-73: `NLTokenizer(unit: .sentence)` + `setLanguage(.english)` |
| `ReadingCoordinator.swift` | `RSVPEngine.swift` | Owns instance, delegates Timer-mode word advancement | WIRED | `private var rsvpEngine: RSVPEngine`; called in `play()`, `pause()`, `resume()`, `loadBook()` |
| `ReadingCoordinator.swift` | `TTSService.swift` | Owns instance, receives word-boundary callbacks | WIRED | `private var ttsService: TTSService`; `ttsService.onWordBoundary = { ... handleTTSWordBoundary ... }` wired in `init` |
| `ReadingCoordinator.swift` | `SpeedCapService.swift` | Queries speed cap before applying WPM | WIRED | `speedCapService.effectiveWPM(requested:forVoice:)` called in `applySpeedCap()`; `speedCapService.wpmToRate` called in `setWPM` and `setVoice` |
| `VoiceManager.swift` | `AVSpeechSynthesisVoice` | `speechVoices()` enumeration | WIRED | Line 71: `AVSpeechSynthesisVoice.speechVoices()` |
| `RSVPDisplayView.swift` | `ReadingCoordinator.swift` | Observes `coordinator.currentWord` | WIRED | `ReadingView.swift` line 189: `RSVPDisplayView(word: coordinator.currentWord)` |
| `ReadingView.swift` | `ReadingCoordinator.swift` | Hosts RSVP display, controls, TTS toggle | WIRED | `@Environment(ReadingCoordinator.self) private var coordinator`; all coordinator state consumed |
| `VoicePickerView.swift` | `VoiceManager.swift` | Displays voices, triggers preview/selection | WIRED | `var voiceManager: VoiceManager` parameter; `voiceManager.installedVoices`, `.previewVoice`, `.selectVoice`, `.openVoiceSettings` all called |
| `BlazeBooksApp.swift` | `ReadingCoordinator.swift` | Creates and injects coordinator as environment object | WIRED | `ReadingCoordinator(speedCapService: speedCap)` created; `.environment(readingCoordinator)` injected |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| READ-01 | 02-01, 02-03 | User can read in RSVP mode (single word display at set WPM) | SATISFIED | `RSVPEngine` + `RSVPDisplayView` + `ReadingView` RSVP mode with segmented toggle; WPM slider 100-500 |
| TTS-01 | 02-01, 02-02, 02-03 | User can enable TTS that syncs with RSVP word display | SATISFIED | `TTSService.onWordBoundary` drives `ReadingCoordinator.handleTTSWordBoundary` which updates `currentWord`; TTS toggle in controls bar |
| TTS-03 | 02-02, 02-03 | Voice speed caps gracefully when WPM exceeds synthesizer capability | SATISFIED | `SpeedCapService.effectiveWPM` clamps; `ReadingCoordinator.applySpeedCap` sets `isSpeedCapped`/`speedCapMessage`; `SpeedCapBanner` shown in RSVP mode |
| TTS-04 | 02-02, 02-03 | User can choose from available Apple built-in voices | SATISFIED | `VoiceManager.installedVoices` via `speechVoices()`; `VoicePickerView` with tap-to-select and checkmark; `ReadingView` voice picker sheet |
| TTS-05 | 02-02, 02-03 | User can download enhanced Apple voice packs on demand | SATISFIED | `VoicePickerView` "Available for Download" section with "Open Voice Settings" button calling `openVoiceSettings()`; `availableVoicesDidChangeNotification` triggers auto-refresh on return |

No orphaned requirements found. REQUIREMENTS.md traceability table marks all 5 requirements as Complete under Phase 2.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None | -- | -- | -- |

No TODO/FIXME/placeholder comments, empty implementations, or stub returns found in any phase 2 files. One known design choice documented: `SpeedCapService.wpmToRate` uses linear interpolation from a 180 WPM baseline, acknowledged as an approximation pending empirical calibration. This is explicit and intentional, not a stub.

One minor structural note: `VoiceManager` declares `downloadGuidanceMessage: String` as an `@Observable` property but it is a static string that never changes. This is harmless but slightly over-engineered; it has no behavioral impact.

One wiring subtlety: `ReadingCoordinator.applySpeedCap()` only triggers the voice cap when `ttsService.currentVoiceIdentifier` is non-nil. On first app launch before the user selects a voice, the identifier is nil, so the cap will not activate even if TTS is enabled. This is expected behavior (TTSService defaults to `en-US` voice when no identifier is set), but the speed cap banner will not show until a voice is explicitly selected. This is acceptable for v1 but worth noting.

### Human Verification Required

#### 1. RSVP ORP Visual Alignment

**Test:** Open an EPUB, switch to RSVP mode, press Play. Observe words appearing one at a time.
**Expected:** The ORP (highlighted accent-colored) letter appears at the exact horizontal center of the display on every word. The before/after text segments are white on the dark background and readable at speeds up to 300+ WPM.
**Why human:** GeometryReader frame math (half-width minus half char-width) is correct in code but visual centering accuracy on physical hardware depends on actual monospace font metrics which may differ from the hardcoded 21.6pt approximation.

#### 2. TTS Synchronization Quality

**Test:** Enable TTS toggle in RSVP mode, press Play. Watch the RSVP display while listening.
**Expected:** The word shown on screen matches the word being spoken at all times. No visible lag between audio and display advancing. Pause/resume correctly re-syncs audio and display.
**Why human:** The `willSpeakRangeOfSpeechString` callback timing and the `wordIndexFromCharRange` NLTokenizer-based word counting must produce exact alignment. This requires runtime audio playback verification.

#### 3. Speed Cap Slider Snap

**Test:** Select a voice in VoicePickerView. Enable TTS. Set WPM slider above 300 (default voice cap).
**Expected:** SpeedCapBanner appears with message "Voice capped at 300 WPM" (or the voice's cap). Slider position snaps back to 300 after release.
**Why human:** Requires TTS to be active with a selected voice for the cap to trigger. The `applySpeedCap` logic is correct but the slider snap behavior (syncing `sliderWPM` back to `effectiveWPM` in `onEditingChanged`) needs runtime confirmation.

### Summary

All ten must-have truths are verified across all three plans. Seven artifacts are fully substantive and wired. All five required artifacts from Plan 03's views are substantive SwiftUI components wired to the engine layer. All key links traced successfully. All 5 requirements (READ-01, TTS-01, TTS-03, TTS-04, TTS-05) are satisfied by implemented code.

The project builds cleanly with zero errors (BUILD SUCCEEDED confirmed). All seven task commits exist in git history (4ae3e06, 5853aec, 4b3b73a, ea112b0, 0804795, 01c3406, 39dab3f). The foreground color bug found during human verification in Plan 03 was corrected (39dab3f).

The phase goal -- "The synchronization engine keeps TTS audio locked to visual word display, with voice selection and graceful speed capping" -- is achieved by the implementation as verified above.

---
_Verified: 2026-02-20T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
