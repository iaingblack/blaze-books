# Phase 2: Reading Engine - Research

**Researched:** 2026-02-20
**Domain:** RSVP display engine, AVSpeechSynthesizer TTS integration, voice management, synchronization
**Confidence:** HIGH (core APIs verified via SDK headers and official docs)

## Summary

Phase 2 builds the synchronized reading engine: RSVP word display with ORP positioning, TTS integration via AVSpeechSynthesizer, voice selection/download management, and graceful speed capping. The core technical challenge is synchronizing visual word display with speech synthesis callbacks, where TTS drives timing when active and a Timer drives timing when TTS is off.

AVSpeechSynthesizer is the only viable TTS option for this project (Apple-only, free, offline). It has known reliability issues with long utterances on iOS 17+ that silently truncate speech. The mandatory mitigation is sentence-level chunking -- never feed more than one sentence per AVSpeechUtterance. Voice downloads cannot be triggered programmatically; the app must guide users to Settings > Accessibility > Live Speech > Voices and observe `availableVoicesDidChangeNotification` for changes.

**Primary recommendation:** Build a three-layer architecture: (1) RSVPEngine handles word timing and ORP calculation, (2) TTSService wraps AVSpeechSynthesizer with sentence-level chunking and delegate-based word tracking, (3) ReadingCoordinator orchestrates both, using TTS word-boundary callbacks to drive RSVP display when TTS is active and Timer-based WPM when TTS is off.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- ORP-aligned (Spritz-style) positioning -- the Optimal Recognition Point letter is always at screen center to reduce eye movement
- ORP letter highlighted with a distinct accent color; rest of word in neutral color
- Natural punctuation pauses -- short pause at commas, longer at periods and paragraph breaks (not strict metronomic timing)
- When idle/paused: last word stays frozen on screen with a play button overlay -- clear resume point
- TTS drives everything -- speech synthesis dictates when the next word appears on screen, WPM becomes approximate when TTS is active
- When TTS is off, WPM timer drives RSVP at exact configured speed
- On resume after pause: back up ~3-5 words before the pause point to help user regain context
- At chapter boundaries: auto-advance with a brief pause, then start the next chapter automatically -- uninterrupted listening
- Voice picker accessible from within the reading view (in-reader settings), not a separate app settings screen
- Tap a voice to hear a short fixed sample phrase -- quick comparison between voices
- Two sections: "Installed" at top, "Available for Download" below -- clear separation with download affordance
- Flat list of English voices only for v1 -- no language/accent grouping
- Per-voice speed cap -- each voice has its own natural maximum WPM; faster voices allow higher speeds
- When WPM exceeds voice capability: inline banner in reading view ("Voice capped at X WPM") -- non-disruptive, stays visible
- Slider snaps to actual capped WPM -- shows reality rather than preserving the user's requested-but-unachievable speed
- Silent RSVP (no TTS) capped at slider max of 500 WPM -- consistent limits regardless of mode

### Claude's Discretion
- Whether RSVP can run without TTS (silent mode) or always implies audio -- decide based on what feels right for the UX
- Exact ORP calculation algorithm (letter position within word)
- Punctuation pause durations (exact milliseconds for comma vs period vs paragraph)
- Sample phrase used for voice preview
- Exact resume backup word count (3-5 range)
- Chapter auto-advance pause duration

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| READ-01 | User can read in RSVP mode (single word display at set WPM) | ORP algorithm, Timer-based timing, punctuation pause multipliers |
| TTS-01 | User can enable TTS that syncs with RSVP word display | AVSpeechSynthesizerDelegate willSpeakRangeOfSpeechString callback, sentence chunking, ReadingCoordinator pattern |
| TTS-03 | Voice speed caps gracefully when WPM exceeds synthesizer capability | Rate range 0.0-1.0, empirical per-voice calibration, inline banner UX |
| TTS-04 | User can choose from available Apple built-in voices | AVSpeechSynthesisVoice.speechVoices(), quality filtering, language filtering |
| TTS-05 | User can download enhanced Apple voice packs on demand | No programmatic download API -- must deep-link to Settings; availableVoicesDidChangeNotification for detection |
</phase_requirements>

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| AVSpeechSynthesizer | iOS 7+ (AVFoundation/AVFAudio) | Text-to-speech synthesis | Apple's only built-in TTS; free, offline, supports word-boundary callbacks |
| AVSpeechSynthesisVoice | iOS 7+ (AVFoundation/AVFAudio) | Voice enumeration, selection, quality filtering | Only API for accessing system voices; quality tiers since iOS 9 |
| AVSpeechUtterance | iOS 7+ (AVFoundation/AVFAudio) | Speech request with rate/pitch/volume control | Required for AVSpeechSynthesizer; sentence-level chunking target |
| Timer (Foundation) | All iOS | WPM-driven RSVP timing when TTS is off | Standard iOS timer; publish/autoconnect pattern in SwiftUI |
| NLTokenizer | iOS 12+ (NaturalLanguage) | Word and sentence tokenization | Already in codebase (WordTokenizer); needed for sentence-level chunking |
| @Observable | iOS 17+ (Observation) | Reactive state for SwiftUI integration | Already used in codebase (ReadingPositionService); drives view updates from engine state |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| AVAudioSession | iOS 3+ (AVFAudio) | Audio session configuration for playback | Required for TTS to work properly; .playback category with .duckOthers |
| NotificationCenter | All iOS | Observe availableVoicesDidChangeNotification | Voice download detection when returning from Settings |
| UIApplication.openURL | All iOS | Deep-link to Settings for voice downloads | TTS-05 requirement; open Accessibility voice settings |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AVSpeechSynthesizer | Third-party TTS (Azure, ElevenLabs) | Requires network, API costs, subscription; out of scope per REQUIREMENTS.md |
| Timer for RSVP | DispatchSourceTimer / CADisplayLink | Timer.publish is simpler for SwiftUI; CADisplayLink only needed for frame-level sync which RSVP doesn't require |
| NLTokenizer sentence splitting | String regex splitting | NLTokenizer handles edge cases (abbreviations, decimal numbers) that regex misses |

**Integration:** No external packages needed. All components are Apple frameworks already available in the project.

## Architecture Patterns

### Recommended Project Structure
```
BlazeBooks/
├── Engines/
│   ├── RSVPEngine.swift          # Word timing, ORP calculation, punctuation pauses
│   ├── TTSService.swift          # AVSpeechSynthesizer wrapper, sentence chunking, delegate
│   └── ReadingCoordinator.swift  # Orchestrates RSVP + TTS, mode switching, chapter advancement
├── Models/
│   ├── ORPWord.swift             # Word with ORP position, display timing
│   └── VoiceInfo.swift           # Voice metadata, quality tier, installed status
├── Services/
│   ├── VoiceManager.swift        # Voice enumeration, filtering, download guidance
│   └── SpeedCapService.swift     # Per-voice WPM calibration and capping
└── Views/
    └── Reading/
        ├── RSVPDisplayView.swift # ORP-aligned single word display
        ├── VoicePickerView.swift # In-reader voice selection sheet
        └── SpeedCapBanner.swift  # Inline "capped at X WPM" banner
```

### Pattern 1: Three-Layer Engine Architecture
**What:** Separate RSVP timing, TTS speech, and coordination into distinct @Observable classes.
**When to use:** Always -- this separation enables TTS-off mode (pure Timer RSVP) and TTS-on mode (delegate-driven RSVP) without tangling logic.
**Example:**
```swift
// ReadingCoordinator.swift
@Observable
final class ReadingCoordinator {
    var currentWord: ORPWord?
    var isPlaying: Bool = false
    var isTTSEnabled: Bool = true

    private let rsvpEngine: RSVPEngine
    private let ttsService: TTSService

    // TTS-on mode: delegate callback drives word advancement
    func ttsDidReachWord(at index: Int) {
        let word = rsvpEngine.word(at: index)
        currentWord = word  // Triggers SwiftUI update
    }

    // TTS-off mode: Timer drives word advancement
    func timerFired() {
        guard !isTTSEnabled else { return }
        rsvpEngine.advanceToNextWord()
        currentWord = rsvpEngine.currentWord
    }
}
```

### Pattern 2: Sentence-Level Chunking for TTS Reliability
**What:** Split chapter text into sentences using NLTokenizer, create one AVSpeechUtterance per sentence, track global word offset across utterances.
**When to use:** Always -- mandatory for iOS 17+ reliability. AVSpeechSynthesizer silently truncates long utterances.
**Example:**
```swift
// TTSService.swift
func prepareChapter(_ text: String) {
    let sentenceTokenizer = NLTokenizer(unit: .sentence)
    sentenceTokenizer.string = text
    sentenceTokenizer.setLanguage(.english)

    var sentences: [(text: String, wordOffset: Int)] = []
    var cumulativeWordCount = 0

    sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
        let sentence = String(text[range])
        sentences.append((text: sentence, wordOffset: cumulativeWordCount))
        cumulativeWordCount += sentence.split(separator: " ").count
        return true
    }

    self.sentenceQueue = sentences
    self.currentSentenceIndex = 0
}

// In delegate callback, translate sentence-local range to global word index
func speechSynthesizer(_ synth: AVSpeechSynthesizer,
                       willSpeakRangeOfSpeechString range: NSRange,
                       utterance: AVSpeechUtterance) {
    let sentenceOffset = sentenceQueue[currentSentenceIndex].wordOffset
    // Convert character range to word index within sentence, add offset
    let globalWordIndex = sentenceOffset + wordIndexFromCharRange(range, in: utterance.speechString)
    delegate?.ttsDidReachWord(at: globalWordIndex)
}
```

### Pattern 3: ORP Calculation with Lookup Table
**What:** Calculate the Optimal Recognition Point letter position based on word length using a proven lookup table from open-source Spritz implementations.
**When to use:** For every word displayed in RSVP mode.
**Example:**
```swift
// Source: https://github.com/pasky/speedread (verified open-source implementation)
struct ORPCalculator {
    /// Returns the zero-based character index of the ORP (Optimal Recognition Point)
    /// for a word of the given length.
    ///
    /// Lookup table: words 1-2 chars -> position 0, 3-6 -> 1, 7-10 -> 2, 11-13 -> 3, 14+ -> 4
    static func orpIndex(forWordLength length: Int) -> Int {
        guard length > 0 else { return 0 }
        if length > 13 { return 4 }
        let table = [0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3]
        return table[length]
    }
}
```

### Pattern 4: @Observable + NSObject Delegate Bridge
**What:** AVSpeechSynthesizerDelegate requires NSObject conformance, but @Observable requires a class. Use an inner NSObject delegate that forwards to the @Observable wrapper.
**When to use:** For TTSService integration with SwiftUI.
**Example:**
```swift
@Observable
final class TTSService {
    var currentWordRange: NSRange = NSRange()
    var isSpeaking: Bool = false

    @ObservationIgnored
    private var synthesizer: AVSpeechSynthesizer
    @ObservationIgnored
    private var delegateHandler: DelegateHandler!

    init() {
        synthesizer = AVSpeechSynthesizer()
        delegateHandler = DelegateHandler(owner: self)
        synthesizer.delegate = delegateHandler
    }

    private class DelegateHandler: NSObject, AVSpeechSynthesizerDelegate {
        weak var owner: TTSService?
        init(owner: TTSService) { self.owner = owner; super.init() }

        func speechSynthesizer(_ synth: AVSpeechSynthesizer,
                               willSpeakRangeOfSpeechString range: NSRange,
                               utterance: AVSpeechUtterance) {
            owner?.currentWordRange = range
        }
        func speechSynthesizer(_ synth: AVSpeechSynthesizer,
                               didFinish utterance: AVSpeechUtterance) {
            owner?.handleUtteranceFinished()
        }
    }
}
```

### Anti-Patterns to Avoid
- **Single long utterance:** Never pass an entire chapter as one AVSpeechUtterance. iOS 17+ silently stops after a few hundred words. Always use sentence-level chunking.
- **Reusing synthesizer after stopSpeaking:** Calling stopSpeaking(at:) can leave AVSpeechSynthesizer in a broken state where future speak() calls are silently ignored. Recreate the synthesizer instance after stop.
- **WPM as exact TTS speed:** AVSpeechUtterance.rate is a 0.0-1.0 float, not WPM. The mapping is nonlinear and voice-dependent. Never assume rate = WPM/500.
- **Queuing many utterances at once:** Don't queue all sentences of a chapter upfront. Queue 1-2 ahead and add more in didFinish. This enables responsive pause/resume and prevents the queue corruption bug.
- **Blocking main thread in delegate callbacks:** willSpeakRangeOfSpeechString fires on an internal AVFoundation thread. Dispatch UI updates to MainActor.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Word tokenization | Custom regex splitter | NLTokenizer (already in codebase) | Handles abbreviations, hyphenated words, contractions; pinned to English per Phase 1 decision |
| Sentence tokenization | String.components(separatedBy: ".") | NLTokenizer(unit: .sentence) | Handles "Dr.", "U.S.A.", decimal numbers, quotes; critical for TTS chunking correctness |
| ORP position | Guess-based centering | Lookup table from speedread (verified algorithm) | Research-backed positions; "roughly first third of word" is vague and wrong for short words |
| Voice enumeration | Hard-coded voice lists | AVSpeechSynthesisVoice.speechVoices() with quality/language filtering | Voice list changes across iOS versions and user downloads; must be dynamic |
| Audio session management | Manual activate/deactivate | usesApplicationAudioSession = false on AVSpeechSynthesizer | System handles ducking, interruptions, mixing automatically (WWDC 2020 recommendation) |
| Synthesizer lifecycle | Singleton synthesizer | Recreate per-chapter or per-error | iOS 17+ bugs corrupt synthesizer state; fresh instances are more reliable |

**Key insight:** AVSpeechSynthesizer is deceptively simple at hello-world level but has deep reliability issues with long content. Every decision should favor defensive chunking, instance recreation, and graceful degradation over optimistic long-lived synthesizer patterns.

## Common Pitfalls

### Pitfall 1: Long Utterance Silent Truncation
**What goes wrong:** AVSpeechSynthesizer stops speaking after ~300-500 words of a long utterance, fires didFinish as if complete, but hasn't spoken the full text.
**Why it happens:** Known iOS 17+ bug in the synthesizer engine. Apple confirmed no workaround via TSI; fix pending.
**How to avoid:** Mandatory sentence-level chunking. One AVSpeechUtterance per sentence. Track global word position across utterances using cumulative word offsets.
**Warning signs:** didFinish fires suspiciously early; word-boundary callbacks stop while text remains.

### Pitfall 2: Synthesizer Instance Corruption After Stop
**What goes wrong:** After calling stopSpeaking(at:), future speak() calls are silently ignored. No delegate callbacks fire.
**Why it happens:** Internal synthesizer state machine enters a locked state after forced stop, especially with queued utterances.
**How to avoid:** After any stopSpeaking() call, nil out the synthesizer and create a fresh instance. Set delegate again on the new instance.
**Warning signs:** speak() returns without error but no audio plays and no delegate callbacks occur.

### Pitfall 3: Rate-to-WPM Mapping Is Nonlinear
**What goes wrong:** Developer assumes rate 0.5 = 250 WPM and rate 1.0 = 500 WPM. Actual speech speed varies wildly per voice.
**Why it happens:** AVSpeechUtterance.rate is a 0.0-1.0 multiplier, not a linear WPM mapping. Different voices have different base speeds. The relationship is approximately exponential, not linear.
**How to avoid:** Empirical calibration per voice. Measure actual WPM at several rate values for each voice, build a lookup/interpolation table. Start with rate 0.5 (default) as ~180 WPM baseline for most English voices, then calibrate from there.
**Warning signs:** Users report speech is "way too fast" or "way too slow" relative to the WPM slider.

### Pitfall 4: Thread Safety with Delegate Callbacks
**What goes wrong:** willSpeakRangeOfSpeechString fires on an AVFoundation background thread. Directly updating @Observable properties causes SwiftUI crashes or visual glitches.
**Why it happens:** AVSpeechSynthesizer delegates are called on internal dispatch queues, not the main thread.
**How to avoid:** Always dispatch to MainActor before updating any @Observable property. Use `Task { @MainActor in ... }` or `DispatchQueue.main.async`.
**Warning signs:** Purple runtime warnings about "Publishing changes from background threads"; occasional crashes in SwiftUI diffing.

### Pitfall 5: Voice Download UX Gap
**What goes wrong:** Developer tries to implement in-app voice download and discovers there is no API for it. User flow breaks because "Available for Download" voices can't actually be downloaded from within the app.
**Why it happens:** Apple provides no programmatic voice download API. Enhanced/premium voices must be downloaded manually via Settings > Accessibility > Live Speech > Voices.
**How to avoid:** Design the "Available for Download" section as a guide, not an action. Tapping a non-installed voice should show a clear explanation and an "Open Settings" button that deep-links to the Accessibility settings. Listen for `availableVoicesDidChangeNotification` when the user returns to refresh the voice list.
**Warning signs:** Attempting to use a non-downloaded enhanced voice identifier -- it simply won't appear in speechVoices() results.

### Pitfall 6: Punctuation Timing Feels Robotic
**What goes wrong:** RSVP displays each word for exactly the same duration. Sentences blur together. Reading feels unnatural.
**Why it happens:** Naive implementation uses constant delay = 60/WPM for every word.
**How to avoid:** Apply timing multipliers based on punctuation: sentence-ending punctuation (.!?) gets 2.5-3x base delay, commas/semicolons get 1.5-2x, paragraph boundaries get 3-4x. Also add a small length penalty for long words: base + 0.04 * sqrt(wordLength). Source: speedread open-source implementation.
**Warning signs:** Users report RSVP feels "robotic" or "hard to follow" even at comfortable WPM.

## Code Examples

Verified patterns from official sources and open-source implementations:

### AVSpeechSynthesizer Basic Setup
```swift
// Source: Apple Developer Documentation + WWDC 2020
import AVFoundation

let synthesizer = AVSpeechSynthesizer()
synthesizer.usesApplicationAudioSession = false  // Let system manage audio

let utterance = AVSpeechUtterance(string: "Hello, world.")
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
utterance.rate = AVSpeechUtteranceDefaultSpeechRate  // 0.5
utterance.pitchMultiplier = 1.0
utterance.volume = 1.0
utterance.preUtteranceDelay = 0.0
utterance.postUtteranceDelay = 0.0

synthesizer.speak(utterance)
```

### Voice Enumeration and Filtering
```swift
// Source: Apple Developer Documentation, Ben Dodson blog (2024)
import AVFoundation

// Get all English voices
let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter {
    $0.language.hasPrefix("en") && $0.voiceTraits != .isNoveltyVoice
}

// Separate by quality/install status
let installedVoices = englishVoices.filter { $0.quality == .default }
let enhancedVoices = englishVoices.filter { $0.quality == .enhanced }
let premiumVoices = englishVoices.filter { $0.quality == .premium }

// Note: enhanced/premium voices only appear if user has downloaded them
// via Settings > Accessibility > Live Speech > Voices

// Listen for voice availability changes
NotificationCenter.default.addObserver(
    forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    // Refresh voice list
    let updatedVoices = AVSpeechSynthesisVoice.speechVoices()
    // Update UI...
}
```

### Word Boundary Tracking via Delegate
```swift
// Source: Hacking with Swift, Apple Developer Documentation
func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                       willSpeakRangeOfSpeechString characterRange: NSRange,
                       utterance: AVSpeechUtterance) {
    let spokenText = utterance.speechString as NSString
    let word = spokenText.substring(with: characterRange)

    // Convert character range to word index
    let prefix = spokenText.substring(to: characterRange.location)
    let wordIndex = prefix.split(separator: " ").count

    Task { @MainActor in
        // Update RSVP display with current word
        coordinator.handleTTSWord(word, at: wordIndex + sentenceWordOffset)
    }
}
```

### ORP Word Display in SwiftUI
```swift
// Source: Derived from speedread ORP algorithm + SwiftUI patterns
struct RSVPDisplayView: View {
    let word: ORPWord  // Contains text, orpIndex, display timing

    var body: some View {
        HStack(spacing: 0) {
            // Characters before ORP -- right-aligned
            Text(word.beforeORP)
                .foregroundStyle(.primary)
                .frame(width: orpLeftWidth, alignment: .trailing)

            // ORP character -- highlighted, fixed position
            Text(word.orpCharacter)
                .foregroundStyle(.accent)
                .fontWeight(.bold)

            // Characters after ORP -- left-aligned
            Text(word.afterORP)
                .foregroundStyle(.primary)
                .frame(width: orpRightWidth, alignment: .leading)
        }
        .font(.system(size: 36, weight: .medium, design: .monospaced))
    }
}
```

### Punctuation-Aware Timing
```swift
// Source: speedread open-source (https://github.com/pasky/speedread)
struct RSVPTimingCalculator {
    /// Calculate display duration for a word at the given WPM.
    static func displayDuration(
        for word: String,
        wpm: Int,
        isSentenceEnd: Bool
    ) -> TimeInterval {
        let baseInterval = 60.0 / Double(wpm)
        var multiplier: Double = 0.9  // Standard word gets slightly less than full interval

        // Length penalty -- longer words need more time
        multiplier += 0.04 * sqrt(Double(word.count))

        // Punctuation pauses
        let lastChar = word.last ?? Character(" ")
        if ".!?".contains(lastChar) || isSentenceEnd {
            multiplier *= 3.0  // Sentence-ending pause
        } else if ",;:".contains(lastChar) {
            multiplier *= 2.0  // Clause pause
        }

        return baseInterval * multiplier
    }
}
```

### Audio Session Configuration
```swift
// Source: WWDC 2020 "Create a seamless speech experience"
import AVFoundation

func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try session.setActive(true)
    } catch {
        print("Audio session configuration failed: \(error)")
    }
}

// Or let the system handle it (preferred per WWDC 2020):
let synthesizer = AVSpeechSynthesizer()
synthesizer.usesApplicationAudioSession = false
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single long AVSpeechUtterance | Sentence-level chunking | iOS 17 (2023) | Mandatory; long utterances silently truncate |
| ObservableObject + @Published | @Observable macro | iOS 17 (2023) | Simpler code; already used in codebase |
| Manual audio session management | usesApplicationAudioSession = false | iOS 13 / WWDC 2020 | System handles ducking/interruptions automatically |
| default + enhanced quality tiers | default + enhanced + premium tiers | iOS 16 (2022) | Premium voices available for download |
| No voice change notification | availableVoicesDidChangeNotification | iOS 16+ | Can detect when user downloads new voices |
| Personal Voice not available | Personal Voice via requestPersonalVoiceAuthorization | iOS 17 (2023) | Out of scope for v1 but exists |
| UIKit attributed string highlighting | SwiftUI Text with ORP layout | Ongoing | No built-in SwiftUI word highlight API; custom view required |

**Deprecated/outdated:**
- AVSpeechSynthesisVoiceIdentifierAlex: Legacy voice identifier; still works but should use speechVoices() filtering instead
- Objective-C delegate patterns: Use Swift + @Observable bridge pattern instead
- Single synthesizer instance for app lifetime: Unreliable on iOS 17+; recreate per-chapter or per-error

## Open Questions

1. **Exact rate-to-WPM calibration per voice**
   - What we know: Rate 0.5 is default, range 0.0-1.0. Default rate is approximately 180 WPM for most English voices. The mapping is nonlinear.
   - What's unclear: Exact WPM at various rate values for each voice. Whether enhanced/premium voices have different rate curves than default voices.
   - Recommendation: Build a calibration mechanism that measures actual speech duration vs word count at a few rate points (0.3, 0.5, 0.7, 0.9) for each voice, then interpolate. Cache results. This is an empirical problem that cannot be solved from documentation alone. Flag in STATE.md as a Phase 2 task requiring device testing.

2. **iOS 18/19 AVSpeechSynthesizer reliability**
   - What we know: iOS 17 had serious long-utterance bugs. Apple was investigating.
   - What's unclear: Whether iOS 18+ has fixed the truncation bug. Our sentence-level chunking mitigation should work regardless.
   - Recommendation: Keep sentence-level chunking as mandatory regardless of iOS version. It's the right architecture anyway (enables word tracking, responsive pause/resume).

3. **Deep link to voice download settings**
   - What we know: UIApplication.open(URL(string: "App-prefs:ACCESSIBILITY")!) can open Accessibility settings. iOS 17.2+ added more URL schemes.
   - What's unclear: Whether there's a specific URL scheme that goes directly to the voice download screen (Accessibility > Live Speech > Voices). URL schemes for Settings are undocumented and may break.
   - Recommendation: Use UIApplication.openURL to open the closest Settings page possible. Fall back to a text explanation if the URL scheme stops working. Test on device.

4. **Silent RSVP mode (no TTS) as default or option**
   - What we know: CONTEXT.md says "Whether RSVP can run without TTS (silent mode) or always implies audio -- decide based on what feels right for the UX"
   - What's unclear: N/A -- this is a UX decision.
   - Recommendation: Support both modes. Default to TTS-off (silent RSVP) since it's simpler and faster. TTS is a toggle the user enables. This makes RSVP the primary feature and TTS the enhancement, matching the "speed reading" positioning.

## Sources

### Primary (HIGH confidence)
- AVSpeechSynthesis.h SDK header (iOS 13 SDK) -- confirmed rate constants, quality enum, delegate methods
- Apple Developer Documentation: AVSpeechSynthesizer, AVSpeechSynthesisVoice, AVSpeechUtterance
- WWDC 2020 "Create a seamless speech experience" -- usesApplicationAudioSession, prefersAssistiveTechnologySettings
- WWDC 2023 "Extend Speech Synthesis with personal and custom voices" -- Personal Voice, availableVoicesDidChangeNotification
- Expo/expo commit 9cbea01 -- confirmed AVSpeechUtteranceDefaultSpeechRate = 0.5
- Hacking with Swift -- willSpeakRangeOfSpeechString delegate pattern
- speedread (github.com/pasky/speedread) -- ORP lookup table, punctuation timing multipliers

### Secondary (MEDIUM confidence)
- Ben Dodson blog (2024) -- voice quality filtering, voiceTraits, no programmatic download API
- Apple Developer Forums thread 737685 -- iOS 17 long utterance truncation bug confirmed
- Apple Developer Forums thread 738048 -- synthesizer corruption after stop, recreate workaround
- AppCoda TTS tutorial -- delegate method integration patterns
- Gist Koze/d1de49c -- English voice identifiers and quality tiers list

### Tertiary (LOW confidence)
- Rate-to-WPM mapping: No authoritative source found. 0.5 = ~180 WPM is based on community reports and Expo normalization code. Empirical testing required. Flag for validation.
- URL scheme for voice settings: Undocumented, community-maintained lists. May break across iOS versions. Flag for validation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all components are Apple frameworks with verified API surface
- Architecture: HIGH -- patterns derived from known AVSpeechSynthesizer limitations and existing codebase conventions
- ORP algorithm: HIGH -- verified from open-source speedread implementation with wide adoption
- Pitfalls: HIGH -- all major pitfalls confirmed via multiple Apple Developer Forum threads and official docs
- Rate calibration: LOW -- no authoritative WPM mapping exists; requires empirical testing
- Voice download UX: MEDIUM -- confirmed no programmatic API; deep-link approach needs device testing

**Research date:** 2026-02-20
**Valid until:** 2026-04-20 (60 days -- AVSpeechSynthesizer API is stable; iOS 19 beta may introduce changes)
