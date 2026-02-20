---
phase: 02-reading-engine
plan: 01
subsystem: reading-engine
tags: [rsvp, orp, tts, avspeechsynthesizer, nltokenizer, timer, observable, ios]

# Dependency graph
requires:
  - phase: 01-foundation-02
    provides: "WordTokenizer for NLTokenizer-based word/sentence tokenization"
provides:
  - "RSVPEngine: Timer-driven word advancement with ORP calculation and punctuation-aware pauses"
  - "TTSService: AVSpeechSynthesizer wrapper with sentence-level chunking and word-boundary tracking"
  - "ORPWord: Word model with ORP index, text segments, sentence-end flag"
  - "VoiceInfo: Voice metadata model with identifier, name, quality tier, installed status"
affects: [02-02, 02-03, phase-3]

# Tech tracking
tech-stack:
  added: [AVFoundation (AVSpeechSynthesizer, AVSpeechSynthesisVoice, AVSpeechUtterance)]
  patterns: [NSObject delegate bridge for @Observable + AVSpeechSynthesizerDelegate, sentence-level TTS chunking with cumulative word offsets, ORP lookup table from speedread, punctuation-aware timing multipliers]

key-files:
  created:
    - BlazeBooks/Models/ORPWord.swift
    - BlazeBooks/Models/VoiceInfo.swift
    - BlazeBooks/Engines/RSVPEngine.swift
    - BlazeBooks/Engines/TTSService.swift
  modified: []

key-decisions:
  - "ORP lookup table uses speedread open-source positions: length 1-2 -> 0, 3-6 -> 1, 7-10 -> 2, 11-13 -> 3, 14+ -> 4"
  - "Resume backs up 4 words before pause point (within CONTEXT.md 3-5 word range) for context recovery"
  - "Punctuation timing: 3.0x for sentence-end, 2.0x for clause, 0.9x base + sqrt length penalty (from speedread)"
  - "TTSService recreates AVSpeechSynthesizer per chapter/start, nils after stop (per iOS 17+ Pitfall 2)"
  - "Sentence word counting uses NLTokenizer(unit: .word) for consistency with WordTokenizer (not String.split)"
  - "usesApplicationAudioSession = false per WWDC 2020 -- system manages audio session ducking/interruptions"

patterns-established:
  - "NSObject delegate bridge: inner DelegateHandler class forwards AVSpeechSynthesizerDelegate to @Observable owner"
  - "Sentence-level TTS: NLTokenizer splits text into sentences, each becomes one AVSpeechUtterance"
  - "Cumulative word offsets: sentenceQueue stores (text, wordOffset) tuples for global-to-local index mapping"
  - "One-shot Timer scheduling: invalidate + reschedule pattern for variable word display durations"
  - "ORP text splitting: beforeORP/orpCharacter/afterORP segments for RSVP display alignment"

requirements-completed: [READ-01, TTS-01]

# Metrics
duration: 4min
completed: 2026-02-20
---

# Phase 2 Plan 01: Core Engines Summary

**RSVP engine with ORP-aligned Timer-driven word advancement and TTS service with sentence-level AVSpeechSynthesizer chunking and word-boundary callbacks**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-20T19:20:58Z
- **Completed:** 2026-02-20T19:25:51Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- RSVPEngine loads chapter text via WordTokenizer, converts to ORPWord array with calculated ORP positions, and advances through words with Timer-based punctuation-aware timing
- TTSService wraps AVSpeechSynthesizer with sentence-level chunking (one utterance per sentence), cumulative word offsets for global word tracking, and NSObject delegate bridge for @Observable compatibility
- ORPWord model splits words into before/ORP/after segments using speedread lookup table for RSVP display alignment
- VoiceInfo model wraps AVSpeechSynthesisVoice metadata with quality tier enum (default/enhanced/premium)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ORPWord, VoiceInfo models and RSVPEngine** - `4ae3e06` (feat)
2. **Task 2: Create TTSService with delegate bridge and sentence chunking** - `5853aec` (feat)

## Files Created/Modified
- `BlazeBooks/Models/ORPWord.swift` - Word model with ORP index calculation, text segments (before/ORP/after), sentence-end flag, and static factory from WordToken
- `BlazeBooks/Models/VoiceInfo.swift` - Voice metadata struct wrapping AVSpeechSynthesisVoice with quality tier enum and Identifiable conformance
- `BlazeBooks/Engines/RSVPEngine.swift` - @Observable Timer-driven engine with loadChapter, play/pause/resume, WPM control, punctuation-aware timing, and ORP word advancement
- `BlazeBooks/Engines/TTSService.swift` - @Observable AVSpeechSynthesizer wrapper with sentence-level chunking, NSObject delegate bridge, word-boundary callbacks, and synthesizer lifecycle management

## Decisions Made
- Used speedread open-source ORP lookup table (verified in research): word length 1-2 -> position 0, 3-6 -> 1, 7-10 -> 2, 11-13 -> 3, 14+ -> 4
- Resume backs up exactly 4 words before pause point (within the CONTEXT.md 3-5 word discretion range)
- Punctuation timing multipliers from speedread: 0.9x base for standard words, 3.0x for sentence-ending (.!?), 2.0x for clause punctuation (,;:), plus 0.04 * sqrt(wordLength) length penalty
- TTSService creates fresh AVSpeechSynthesizer per speak() call and nils it after stop() -- mandatory for iOS 17+ reliability (Pitfall 2)
- NLTokenizer(unit: .word) used for sentence word counting in TTSService to ensure consistency with WordTokenizer (not String.split which handles edge cases differently)
- usesApplicationAudioSession = false on synthesizer per WWDC 2020 recommendation -- lets system manage audio session ducking and interruptions automatically
- postUtteranceDelay = 0.05 seconds between sentences for natural speech flow without noticeable gaps
- Timer added to RunLoop.main with .common mode to ensure RSVP timing fires during scroll tracking and UI interactions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unused variable warning in TTSService.speak(fromWordIndex:)**
- **Found during:** Task 2 (TTSService build verification)
- **Issue:** Compiler warning: `immutable value 'sentence' was never used` in the sentence-finding loop
- **Fix:** Changed `for (index, sentence)` to `for (index, _)` since only the index is used for offset comparison
- **Files modified:** BlazeBooks/Engines/TTSService.swift
- **Verification:** Clean build with zero warnings
- **Committed in:** 5853aec (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial unused variable fix. No scope creep.

## Issues Encountered
None -- both files compiled cleanly on first build. The only issue was a minor unused variable warning caught during verification and fixed immediately.

## User Setup Required

None - no external service configuration required. All components use Apple frameworks already available in the project.

## Next Phase Readiness
- RSVPEngine and TTSService are ready for Plan 02 (ReadingCoordinator) to orchestrate both engines
- RSVPEngine exposes `word(at:)` for coordinator to look up words by TTS callback index
- TTSService exposes `onWordBoundary` callback for coordinator to drive RSVP display in TTS-on mode
- Both engines expose `onChapterComplete` closures for chapter auto-advancement
- ORPWord segments (beforeORP/orpCharacter/afterORP) ready for RSVPDisplayView in Phase 3

## Self-Check: PASSED

All 4 created files verified on disk. Both task commits (4ae3e06, 5853aec) verified in git history. Clean build succeeds with zero errors and zero warnings.

---
*Phase: 02-reading-engine*
*Completed: 2026-02-20*
