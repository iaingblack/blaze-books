# Phase 3: Reading Experience - Research

**Researched:** 2026-02-20
**Domain:** SwiftUI page mode reading with word-level TTS highlighting, mode switching, WPM speed control
**Confidence:** HIGH (core patterns verified via Apple docs, Context7, existing codebase analysis)

## Summary

Phase 3 adds page mode reading (scrollable text with word-by-word highlighting during TTS), mode switching between RSVP and page mode preserving exact word position, and a WPM speed slider (100-500). The primary technical challenge is rendering a scrollable chapter text where the currently spoken word is highlighted in real time as TTS speaks, and auto-scrolling the view to keep the highlighted word visible.

The recommended approach uses **paragraph-level AttributedString** rendering within a LazyVStack. Each paragraph is a Text view displaying an AttributedString where the currently highlighted word has a distinct backgroundColor. When the TTS word-boundary callback fires, the coordinator updates the current word index, which triggers an AttributedString rebuild for only the affected paragraph(s). ScrollViewReader with `.scrollTo(paragraphID)` keeps the active paragraph visible. This approach avoids per-word Text concatenation (which has poor performance at chapter scale) and avoids UIKit bridging (which breaks SwiftUI observation patterns already used throughout the codebase).

A critical discovery: **AVSpeechUtterance.rate cannot be changed during speech**. When the user adjusts the WPM slider while TTS is active, the app must stop the current utterance, note the current word position via the last word-boundary callback, and restart speech from that position with a new utterance at the updated rate. For RSVP-only mode (TTS off), the RSVPEngine timer interval can be updated in-place immediately.

**Primary recommendation:** Build a PageModeView that renders paragraphs as Text(AttributedString) views in a LazyVStack inside ScrollViewReader. Extend ReadingCoordinator with a `readingMode` enum (.rsvp / .page) and a `highlightedWordIndex` property. Map word indices to paragraph indices for both highlighting and auto-scroll. Reuse existing TTSService word-boundary callbacks (already working from Phase 2) to drive highlighting.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| READ-02 | User can read in page mode (full page with highlighted current word) | Paragraph-level AttributedString with backgroundColor for word highlighting, LazyVStack + ScrollViewReader for auto-scroll |
| READ-03 | User can toggle between RSVP and page mode mid-session without losing position | ReadingCoordinator.currentWordIndex is the shared position source; mode switch reads/writes this single value |
| TTS-02 | User can enable TTS that syncs with page mode word highlighting | TTSService.onWordBoundary callback (already implemented) drives highlightedWordIndex; same sentence-level chunking from Phase 2 |
| NAV-01 | User can adjust reading speed via WPM slider (100-500 range) | SwiftUI Slider with step:10, onChange updates RSVPEngine immediately; TTS requires stop/restart from current word with new rate |
</phase_requirements>

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| AttributedString | iOS 15+ (Foundation) | Word-level highlighting with backgroundColor in Text views | Native Swift type; SwiftUI Text renders it directly; no UIKit bridging needed |
| ScrollViewReader / ScrollViewProxy | iOS 14+ (SwiftUI) | Programmatic scroll-to-paragraph during TTS playback | Apple's official API for programmatic scrolling; already used in existing ReadingView |
| LazyVStack | iOS 14+ (SwiftUI) | Lazy paragraph rendering for chapter text | Only renders visible paragraphs; critical for long chapters |
| ReadingCoordinator (existing) | Phase 2 | Central state machine for word tracking, TTS coordination | Already owns currentWordIndex, isTTSEnabled, chapter management |
| TTSService (existing) | Phase 2 | Word-boundary callbacks via onWordBoundary closure | Already implemented with sentence-level chunking and global word index tracking |
| RSVPEngine (existing) | Phase 2 | Timer-driven word advancement for RSVP mode | Already handles WPM timing, punctuation pauses, chapter completion |
| WordTokenizer (existing) | Phase 1 | NLTokenizer-based word/sentence tokenization | Already used throughout; provides WordToken with range for character-to-word mapping |
| Slider | iOS 13+ (SwiftUI) | WPM speed control (100-500 range) | Already partially implemented in ReadingView; needs extraction and shared behavior |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| SpeedCapService (existing) | Phase 2 | Per-voice WPM capping | When TTS is enabled and user changes WPM |
| ReadingPositionService (existing) | Phase 1 | Debounced position persistence to SwiftData | Position saves during page mode reading (scroll-based and word-based) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AttributedString in Text | Text concatenation with + operator | Per-word Text + is cleaner per-word but has poor performance at chapter scale (hundreds of words); AttributedString mutates a single struct |
| AttributedString in Text | TextRenderer (iOS 18+) | TextRenderer is more powerful but requires iOS 18+ minimum deployment; incompatible with textSelection per FatBobMan research; overkill for simple background color highlighting |
| LazyVStack paragraphs | UITextView via UIViewRepresentable | UIKit bridging breaks @Observable patterns used throughout; adds complexity; NSAttributedString is legacy API |
| ScrollViewReader.scrollTo | scrollPosition(id:) (iOS 17+) | scrollPosition is newer but requires scrollTargetLayout(); ScrollViewReader is simpler and already used in the codebase |

**Integration:** No external packages needed. All components are Apple frameworks or existing project code.

## Architecture Patterns

### Recommended Project Structure
```
BlazeBooks/
├── Engines/
│   ├── RSVPEngine.swift              # (existing) Timer-driven RSVP -- no changes needed
│   ├── TTSService.swift              # (existing) TTS with word-boundary callbacks -- no changes needed
│   └── ReadingCoordinator.swift      # EXTEND: add readingMode, page mode support
├── Models/
│   ├── ORPWord.swift                 # (existing) -- no changes needed
│   └── ReadingMode.swift             # NEW: enum ReadingMode { case rsvp, page }
├── Services/
│   ├── WordTokenizer.swift           # (existing) -- no changes needed
│   ├── SpeedCapService.swift         # (existing) -- no changes needed
│   ├── ReadingPositionService.swift  # (existing) -- no changes needed
│   └── PageTextService.swift         # NEW: paragraph splitting, word-to-paragraph mapping, AttributedString generation
├── Views/
│   └── Reading/
│       ├── RSVPDisplayView.swift     # (existing) -- no changes needed
│       ├── ReadingView.swift         # MODIFY: integrate PageModeView, shared WPM slider, mode switching
│       ├── PageModeView.swift        # NEW: scrollable text with word highlighting
│       ├── WPMSliderView.swift       # NEW: extracted reusable WPM slider (shared by both modes)
│       ├── VoicePickerView.swift     # (existing) -- no changes needed
│       └── SpeedCapBanner.swift      # (existing) -- no changes needed
```

### Pattern 1: Paragraph-Level AttributedString Highlighting
**What:** Render chapter text as paragraphs in a LazyVStack. Each paragraph is a Text(AttributedString). When the current word changes, rebuild only the affected paragraph's AttributedString with backgroundColor on the highlighted word.
**When to use:** Always for page mode rendering.
**Why:** Avoids per-word view creation (Text + operator for 1000+ words is slow). AttributedString mutation is a value-type operation -- rebuild the paragraph string, swap it, SwiftUI diffs only the changed paragraph.
**Example:**
```swift
// PageTextService.swift
struct ParagraphData: Identifiable {
    let id: String                    // "ch0-p3" stable paragraph ID
    let text: String                  // raw paragraph text
    let wordRange: Range<Int>         // global word indices this paragraph covers (e.g., 45..<78)
}

func attributedString(for paragraph: ParagraphData, highlightedWordIndex: Int?) -> AttributedString {
    var attributed = AttributedString(paragraph.text)

    guard let highlightIndex = highlightedWordIndex,
          paragraph.wordRange.contains(highlightIndex) else {
        return attributed
    }

    // Find the word's character range within this paragraph
    let localIndex = highlightIndex - paragraph.wordRange.lowerBound
    let tokens = tokenizer.tokenize(paragraph.text)
    guard localIndex < tokens.count else { return attributed }
    let token = tokens[localIndex]

    // Convert String.Index range to AttributedString.Index range
    if let lower = AttributedString.Index(token.range.lowerBound, within: attributed),
       let upper = AttributedString.Index(token.range.upperBound, within: attributed) {
        attributed[lower..<upper].backgroundColor = .accentColor.opacity(0.3)
        attributed[lower..<upper].foregroundColor = .primary
    }

    return attributed
}
```

### Pattern 2: Word-to-Paragraph Mapping for Auto-Scroll
**What:** Pre-compute a mapping from global word index to paragraph ID at chapter load time. When the highlighted word changes, look up which paragraph it belongs to and call scrollTo(paragraphID) if it differs from the currently visible paragraph.
**When to use:** Always for page mode auto-scrolling during TTS playback.
**Example:**
```swift
// PageTextService.swift
func paragraphIndex(forWordIndex wordIndex: Int, paragraphs: [ParagraphData]) -> Int? {
    paragraphs.firstIndex { $0.wordRange.contains(wordIndex) }
}

// PageModeView.swift -- in onChange(of: coordinator.currentWordIndex)
if let pIdx = pageTextService.paragraphIndex(forWordIndex: newIndex, paragraphs: paragraphs),
   pIdx != lastScrolledParagraph {
    lastScrolledParagraph = pIdx
    withAnimation(.easeInOut(duration: 0.3)) {
        proxy.scrollTo(paragraphs[pIdx].id, anchor: .center)
    }
}
```

### Pattern 3: Mode Switching via Shared Word Index
**What:** ReadingCoordinator.currentWordIndex is the single source of truth for reading position across both modes. Switching modes reads the current index, pauses the old mode, and starts the new mode from that exact index.
**When to use:** Always for RSVP/page mode switching.
**Example:**
```swift
// ReadingCoordinator.swift
enum ReadingMode {
    case rsvp
    case page
}

func switchMode(to newMode: ReadingMode) {
    let savedIndex = currentWordIndex
    let wasTTSPlaying = isPlaying && isTTSEnabled

    // Stop current mode
    stop()

    readingMode = newMode

    // In page mode, we don't use RSVPEngine's timer -- TTS drives word advancement
    // In RSVP mode, RSVPEngine timer OR TTS drives word advancement (existing behavior)

    currentWordIndex = savedIndex
    currentWord = rsvpEngine.word(at: savedIndex)

    // If TTS was playing, resume from same position
    if wasTTSPlaying {
        play()
    }
}
```

### Pattern 4: TTS Rate Change via Stop-Restart
**What:** AVSpeechUtterance.rate cannot be modified after speech starts. To change WPM during TTS playback, stop the current utterance, note the current word index, and restart from that word with a new rate.
**When to use:** Always when the user adjusts the WPM slider while TTS is actively speaking.
**Example:**
```swift
// ReadingCoordinator.swift
func setWPM(_ wpm: Int) {
    currentWPM = max(100, min(500, wpm))
    applySpeedCap()

    // Update RSVP timer immediately (no restart needed)
    rsvpEngine.setWPM(effectiveWPM)

    // For TTS: must stop and restart with new rate
    if isTTSEnabled, isPlaying {
        let resumeIndex = currentWordIndex
        ttsService.stop()
        if let voiceId = ttsService.currentVoiceIdentifier {
            ttsService.setRate(speedCapService.wpmToRate(effectiveWPM, forVoice: voiceId))
        }
        ttsService.speak(fromWordIndex: resumeIndex)
    } else if let voiceId = ttsService.currentVoiceIdentifier {
        ttsService.setRate(speedCapService.wpmToRate(effectiveWPM, forVoice: voiceId))
    }
}
```

### Anti-Patterns to Avoid
- **Per-word Text views in ForEach/HStack:** Never create individual Text views for each word and lay them out in an HStack or FlowLayout. This creates thousands of views for a single chapter, devastating SwiftUI performance. Use paragraph-level Text(AttributedString) instead.
- **Full chapter as single AttributedString:** A single Text view with a 10,000-word AttributedString will cause layout stutters on each highlight change. Split into paragraphs so only one paragraph's AttributedString is rebuilt per word advance.
- **Modifying AVSpeechUtterance.rate during speech:** Properties are read-only once speech begins. The utterance must be stopped and a new one created with the desired rate.
- **Animating word highlights:** Do not animate the backgroundColor transition between words. At TTS speaking speed (150-400 WPM), animation delays cause visual lag where the highlight trails behind the speech. Use instant, non-animated updates.
- **Bridging to UITextView for highlighting:** Avoid UIViewRepresentable with UITextView/NSAttributedString. It breaks the @Observable patterns used throughout the codebase and introduces UIKit lifecycle complexity. SwiftUI's Text(AttributedString) is sufficient for word-level backgroundColor highlighting.
- **Tokenizing paragraph text on every word change:** Cache the tokenized words for each paragraph at chapter load time. Re-tokenizing on every word boundary callback (every ~200ms at 300 WPM) wastes CPU cycles.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Word highlighting in text | Custom overlay views or per-word Text layout | AttributedString with backgroundColor | Handles line wrapping, variable fonts, and RTL automatically |
| Paragraph auto-scrolling | Manual scroll offset calculation | ScrollViewReader.scrollTo(id:) | Handles safe areas, navigation bars, dynamic content correctly |
| Word-to-paragraph mapping | On-the-fly search every word change | Pre-computed ParagraphData with wordRange | Binary search or direct lookup avoids O(n) per word at 300 WPM |
| TTS word position tracking | Custom character counting | TTSService.onWordBoundary (existing) | Already handles sentence-level chunking, global word offset, NLTokenizer consistency |
| WPM-to-TTS rate conversion | Manual rate = wpm/500 formula | SpeedCapService.wpmToRate (existing) | Already handles nonlinear mapping, per-voice caps, clamping |
| Mode switching position | Separate position state per mode | ReadingCoordinator.currentWordIndex | Single source of truth prevents position drift between modes |

**Key insight:** Phase 3's complexity is orchestration, not new algorithms. The engines (RSVPEngine, TTSService, WordTokenizer) are already built. The challenge is wiring the existing word-boundary callbacks to a new paragraph-level view, and handling the AVSpeechUtterance immutability constraint during speed changes.

## Common Pitfalls

### Pitfall 1: AttributedString Rebuild Performance
**What goes wrong:** Rebuilding the entire chapter's AttributedString on every word change (every ~150-400ms) causes frame drops and UI stutter.
**Why it happens:** A chapter can be 5,000-15,000 words across 50-200 paragraphs. Rebuilding all paragraphs when only one word changes is O(n) wasted work.
**How to avoid:** Only rebuild the AttributedString for the paragraph containing the highlighted word. Track `lastHighlightedParagraph` and only update two paragraphs max per word change (the previous and current). LazyVStack ensures off-screen paragraphs don't render at all.
**Warning signs:** Dropped frames during TTS playback; highlight appears to "lag" behind speech.

### Pitfall 2: TTS Rate Change Causes Position Jump
**What goes wrong:** User adjusts WPM slider during TTS playback. The app stops TTS and restarts from what it thinks is the current word, but the position is off by a few words.
**Why it happens:** The last onWordBoundary callback may not reflect the actual word being spoken at stop time (there's latency between the callback and actual speech). Stopping mid-word means the spoken position is ahead of the last callback.
**How to avoid:** Accept that the restart position may be off by 1-2 words. This is acceptable UX -- the user just changed speed, so a brief re-read of 1-2 words provides natural context recovery (similar to the 4-word backup on resume from pause).
**Warning signs:** Users report hearing the same words repeated or words being skipped when adjusting speed.

### Pitfall 3: Scroll Thrashing During Fast TTS
**What goes wrong:** At high WPM, the auto-scroll fires rapidly as words advance through paragraphs, causing the scroll view to jitter.
**Why it happens:** scrollTo() is called every time the highlighted word crosses a paragraph boundary, which at 400 WPM with short paragraphs can be multiple times per second.
**How to avoid:** Throttle scroll-to calls. Only auto-scroll when the paragraph ID actually changes (not on every word). Use a smooth animation duration (0.3s) that completes before the next paragraph boundary at typical reading speeds. Avoid scrollTo if the target paragraph is already fully visible.
**Warning signs:** Visible jitter in page mode during TTS playback; scroll position oscillates.

### Pitfall 4: Mode Switch Loses Position When Paragraphs Don't Align With Words
**What goes wrong:** User is in page mode at word index 523 (paragraph 12), switches to RSVP, then back to page mode. The scroll position jumps to the wrong paragraph.
**Why it happens:** The word-to-paragraph mapping wasn't computed or was computed with different tokenization than what RSVP uses.
**How to avoid:** Use the same WordTokenizer for both paragraph word range computation and RSVPEngine/TTSService tokenization. The tokenizer is already pinned to NLLanguage.english for consistency (Phase 1 decision). Always compute paragraph word ranges using the same tokenizer instance.
**Warning signs:** After mode switch, the highlighted word doesn't match what was last displayed in the other mode.

### Pitfall 5: WPM Slider Feels Laggy in TTS Mode
**What goes wrong:** Each slider tick triggers stop/restart of TTS, which has audible gaps and latency.
**Why it happens:** AVSpeechSynthesizer stop/restart takes ~100-200ms. If the slider onChange fires continuously, TTS restarts dozens of times during a drag.
**How to avoid:** Debounce TTS restart. Apply the WPM change to RSVPEngine immediately (cheap), but only restart TTS when the slider drag ends (use Slider's onEditingChanged callback). During the drag, show the new WPM visually but defer the TTS restart until editing completes.
**Warning signs:** Audio stuttering and gaps when dragging the WPM slider; the synthesizer gets into a corrupted state from rapid stop/restart cycles.

### Pitfall 6: willSpeakRangeOfSpeechString Returns Wrong Character Range
**What goes wrong:** The NSRange returned by the TTS delegate callback is offset from the actual word position, causing the wrong word to be highlighted.
**Why it happens:** Known AVSpeechSynthesizer bug where certain words (numbers like "2020", abbreviations) cause the character range to accumulate an offset that persists for the rest of the utterance.
**How to avoid:** The existing TTSService already converts character ranges to word indices via NLTokenizer (not raw character offsets), which is more resilient to range drift. The sentence-level chunking resets any drift at each sentence boundary. Keep this architecture. If drift is observed within a sentence, add a sanity check: if the reported character range exceeds the utterance string length, clamp or skip the callback.
**Warning signs:** Highlighted word drifts from the spoken word partway through a sentence; drift resets at sentence boundaries.

## Code Examples

Verified patterns from official sources and existing codebase:

### Page Mode View with Word Highlighting
```swift
// PageModeView.swift
struct PageModeView: View {
    let paragraphs: [ParagraphData]
    let highlightedWordIndex: Int?
    let chapterTitle: String

    @State private var lastScrolledParagraph: Int = -1

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Chapter header
                    Text(chapterTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        .id("chapter-header")

                    // Paragraphs with word highlighting
                    ForEach(paragraphs) { paragraph in
                        Text(attributedString(for: paragraph))
                            .font(.system(size: 17))
                            .lineSpacing(7)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                            .id(paragraph.id)
                            // Disable animation for instant highlight swap
                            .transaction { $0.animation = nil }
                    }

                    Spacer().frame(height: 100)
                }
            }
            .onChange(of: highlightedWordIndex) { _, newIndex in
                guard let newIndex = newIndex else { return }
                // Auto-scroll to the paragraph containing the highlighted word
                if let pIdx = paragraphs.firstIndex(where: { $0.wordRange.contains(newIndex) }),
                   pIdx != lastScrolledParagraph {
                    lastScrolledParagraph = pIdx
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(paragraphs[pIdx].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func attributedString(for paragraph: ParagraphData) -> AttributedString {
        var attributed = AttributedString(paragraph.text)

        guard let highlightIndex = highlightedWordIndex,
              paragraph.wordRange.contains(highlightIndex) else {
            return attributed
        }

        // Highlight the specific word
        let localIndex = highlightIndex - paragraph.wordRange.lowerBound
        let tokenizer = WordTokenizer()
        let tokens = tokenizer.tokenize(paragraph.text)
        guard localIndex < tokens.count else { return attributed }
        let token = tokens[localIndex]

        if let lower = AttributedString.Index(token.range.lowerBound, within: attributed),
           let upper = AttributedString.Index(token.range.upperBound, within: attributed) {
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.4)
            attributed[lower..<upper].foregroundColor = .primary
        }

        return attributed
    }
}
```

### Debounced WPM Slider for Both Modes
```swift
// WPMSliderView.swift
struct WPMSliderView: View {
    @Binding var sliderWPM: Double
    let effectiveWPM: Int
    let isSpeedCapped: Bool
    let onWPMChanged: (Int) -> Void          // Called continuously during drag
    let onWPMChangeEnded: (Int) -> Void       // Called when drag ends (for TTS restart)

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("100").font(.caption2).foregroundStyle(.secondary)
                Slider(
                    value: $sliderWPM,
                    in: 100...500,
                    step: 10
                ) {
                    Text("WPM")
                } onEditingChanged: { editing in
                    if !editing {
                        onWPMChangeEnded(Int(sliderWPM))
                        // Snap to effective WPM after cap
                        sliderWPM = Double(effectiveWPM)
                    }
                }
                .onChange(of: sliderWPM) { _, newValue in
                    onWPMChanged(Int(newValue))
                }
                Text("500").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}
```

### ReadingCoordinator Mode Extension
```swift
// ReadingCoordinator extension for Phase 3
// Add to ReadingCoordinator.swift

/// The word index currently highlighted in page mode (driven by TTS callbacks or manual position).
/// Page mode views observe this to update their AttributedString highlighting.
var highlightedWordIndex: Int? {
    isPlaying ? currentWordIndex : nil
}

/// Reading mode enum
enum ReadingMode: String, CaseIterable {
    case page = "Page"
    case rsvp = "RSVP"
}

/// Current reading mode (page or RSVP).
var readingMode: ReadingMode = .page
```

### AttributedString Word Range Highlighting
```swift
// Source: Apple Developer Documentation (AttributedString)
// Applying backgroundColor to a character range within an AttributedString

var text = AttributedString("The quick brown fox jumps over the lazy dog.")

// Find the range of "brown"
if let range = text.range(of: "brown") {
    text[range].backgroundColor = .yellow
    text[range].foregroundColor = .black
}

// Display in SwiftUI
Text(text)
    .font(.body)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSAttributedString + UITextView | AttributedString + SwiftUI Text | iOS 15 (2021) | Native Swift value type; works directly with SwiftUI Text views |
| ScrollViewProxy.scrollTo only | scrollPosition(id:anchor:) binding | iOS 17 (2023) | Newer but requires scrollTargetLayout(); ScrollViewProxy is simpler for our use case |
| TextRenderer for highlighting | AttributedString backgroundColor | iOS 18 vs iOS 15 | TextRenderer is more powerful but requires iOS 18+; AttributedString is sufficient and simpler |
| Modify utterance rate mid-speech | Stop + restart with new utterance | Always (iOS 7+) | AVSpeechUtterance properties are immutable once speech begins; has always required stop/restart |
| ObservableObject + @Published | @Observable macro | iOS 17 (2023) | Already used throughout codebase; no migration needed |

**Deprecated/outdated:**
- NSAttributedString for SwiftUI: Use AttributedString (Swift-native) instead. NSAttributedString requires UIKit bridging.
- UITextView wrapping for word highlighting: Not needed -- SwiftUI Text now supports AttributedString with backgroundColor since iOS 15.
- TextRenderer (iOS 18+): Too new for deployment target; breaks with textSelection; overkill for simple word highlighting.

## Open Questions

1. **Per-paragraph token caching vs re-tokenization performance**
   - What we know: WordTokenizer.tokenize() uses NLTokenizer which is reasonably fast. Chapters typically have 50-200 paragraphs.
   - What's unclear: Whether caching tokenized words per paragraph at chapter load time provides meaningful speedup vs re-tokenizing the ~50-word active paragraph on each word change.
   - Recommendation: Cache paragraph tokens at chapter load time in ParagraphData. The memory cost is low (array of WordToken structs per paragraph) and eliminates any risk of frame drops from repeated NLTokenizer calls at TTS speed. If memory becomes a concern on very long chapters, cache only visible paragraphs.

2. **Scroll anchor during auto-scroll: .center vs .top**
   - What we know: .center places the highlighted paragraph in the middle of the screen. .top aligns it to the top.
   - What's unclear: Which feels more natural for a reading app. Center keeps context above and below; top maximizes readable text below.
   - Recommendation: Start with .center and validate during testing. This is a UX tuning question, not an architecture decision. Easy to change.

3. **Page mode without TTS (manual reading)**
   - What we know: Page mode should work as a static scrollable text view when TTS is off, identical to the current page mode behavior (Phase 1). Word highlighting only activates when TTS is playing.
   - What's unclear: Whether users expect any visual indicator of their last RSVP position when switching to page mode with TTS off.
   - Recommendation: When TTS is off in page mode, show the text without highlighting. Scroll to the paragraph containing currentWordIndex so the user sees approximately where they were. This is the simplest approach and avoids confusing "frozen highlight" that doesn't advance.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: AttributedString, Text(AttributedString), backgroundColor attribute
- Apple Developer Documentation: ScrollViewReader, ScrollViewProxy.scrollTo(id:anchor:)
- Apple Developer Documentation: AVSpeechUtterance (rate property is read-only after speech begins)
- Context7 /websites/developer_apple_swiftui -- AttributedString rendering, ScrollViewReader usage patterns
- Existing codebase analysis: ReadingCoordinator.swift, TTSService.swift, RSVPEngine.swift, ReadingView.swift, WordTokenizer.swift

### Secondary (MEDIUM confidence)
- FatBobMan "Implementing Keyword-based Search and Positioning in SwiftUI Text" -- AttributedString range highlighting + ScrollViewProxy positioning pattern
- FatBobMan "A Deep Dive into SwiftUI Rich Text Layout" -- performance analysis of Text concatenation vs AttributedString vs UIKit approaches
- Hacking with Swift "How to highlight text to speech words being read using AVSpeechSynthesizer" -- willSpeakRangeOfSpeechString delegate pattern for word highlighting
- Hacking with Swift "How to make a scroll view move to a location using ScrollViewReader" -- scrollTo with animation patterns
- Apple Developer Forums thread 133104 -- willSpeakRangeOfSpeechString character range offset bug (reported fixed in iOS 16+)
- Apple Developer Forums thread 692192 -- AVSpeechSynthesizer wrong character ranges with specific words
- AppCoda "How to Use ScrollViewReader to Perform Programmatic Scrolling" -- practical ScrollViewReader patterns

### Tertiary (LOW confidence)
- Performance of AttributedString rebuild at TTS word-change frequency: No authoritative benchmark found. Community reports suggest "no bottleneck" for thousands of records, but paragraph-level granularity is the safe approach. Flag for device testing.
- Exact latency of TTS stop/restart during WPM change: No documentation on AVSpeechSynthesizer restart latency. Estimated 100-200ms based on community reports. Debouncing slider to onEditingChanged mitigates this. Flag for device testing.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all components are Apple frameworks or existing project code; APIs verified via Context7 and official docs
- Architecture: HIGH -- paragraph-level AttributedString pattern is well-documented; mode switching via shared word index is a straightforward state management pattern
- Page mode highlighting: HIGH -- AttributedString.backgroundColor is a documented, supported feature since iOS 15
- TTS sync in page mode: HIGH -- reuses existing TTSService.onWordBoundary callbacks from Phase 2
- WPM slider with TTS restart: HIGH -- AVSpeechUtterance rate immutability confirmed via multiple Apple Developer Forum threads and official docs
- Pitfalls: MEDIUM -- willSpeakRangeOfSpeechString range bug is documented but marked as fixed in iOS 16+; performance claims need device validation
- Auto-scroll UX: LOW -- scroll anchor choice (.center vs .top) needs user testing

**Research date:** 2026-02-20
**Valid until:** 2026-04-20 (60 days -- SwiftUI Text/AttributedString API is stable; no expected breaking changes)
