---
phase: 03-reading-experience
plan: 01
subsystem: engine
tags: [swift, swiftui, attributedstring, rsvp, tts, reading-mode, page-mode, word-highlighting]

# Dependency graph
requires:
  - phase: 02-reading-engine
    provides: ReadingCoordinator, RSVPEngine, TTSService, WordTokenizer, SpeedCapService
provides:
  - ReadingMode enum (.page, .rsvp) with CaseIterable for Picker display
  - PageTextService with ParagraphData model, paragraph splitting, word-to-paragraph lookup, AttributedString highlighting
  - ReadingCoordinator.readingMode for tracking current reading mode
  - ReadingCoordinator.highlightedWordIndex computed property for page mode views
  - ReadingCoordinator.switchMode(to:) preserving word position across mode transitions
  - ReadingCoordinator.commitWPMChange() for debounced TTS restart on slider drag end
affects: [03-02-page-mode-views, reading-experience, ui-integration]

# Tech tracking
tech-stack:
  added: [AttributedString-highlighting, paragraph-level-text-processing]
  patterns: [stateless-service-struct, cached-paragraph-tokens, debounced-tts-restart, mode-switching-via-shared-index]

key-files:
  created:
    - BlazeBooks/Models/ReadingMode.swift
    - BlazeBooks/Services/PageTextService.swift
  modified:
    - BlazeBooks/Engines/ReadingCoordinator.swift

key-decisions:
  - "ReadingMode defaults to .rsvp (preserves existing behavior as primary mode)"
  - "PageTextService is a struct (stateless service like WordTokenizer, not @Observable)"
  - "ParagraphData caches WordTokens at split time to avoid re-tokenization per word highlight change"
  - "highlightedWordIndex returns nil when paused (no frozen highlight in page mode)"
  - "setWPM only updates RSVPEngine; commitWPMChange debounces TTS restart to slider drag end"

patterns-established:
  - "Cached paragraph tokens: pre-tokenize at chapter load, not per word change"
  - "Debounced TTS restart: continuous updates to engine state, deferred TTS stop/restart"
  - "Mode switching via shared word index: save/restore currentWordIndex across transitions"

requirements-completed: [READ-02, TTS-02, NAV-01]

# Metrics
duration: 4min
completed: 2026-02-20
---

# Phase 3 Plan 1: Page Mode Engine Layer Summary

**ReadingMode enum, PageTextService with paragraph-level AttributedString highlighting, and ReadingCoordinator extensions for mode switching and debounced WPM control**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-20T21:07:44Z
- **Completed:** 2026-02-20T21:12:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- ReadingMode enum with .page and .rsvp cases for segmented Picker display
- PageTextService splits chapter text into ParagraphData with pre-computed word ranges and cached tokens for O(1) word-to-paragraph lookup
- AttributedString generation with yellow background word highlighting using cached tokens (no re-tokenization per word change)
- ReadingCoordinator extended with readingMode, highlightedWordIndex, switchMode(to:), and commitWPMChange() without breaking existing RSVP functionality
- Page mode without TTS skips RSVPEngine timer (passive scroll reading)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ReadingMode enum and PageTextService** - `fa04f6f` (feat)
2. **Task 2: Extend ReadingCoordinator with mode switching and debounced WPM** - `59fb7d1` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `BlazeBooks/Models/ReadingMode.swift` - ReadingMode enum (.page, .rsvp) with CaseIterable and raw String values
- `BlazeBooks/Services/PageTextService.swift` - Stateless service with ParagraphData model, splitIntoParagraphs, paragraphIndex, and attributedString methods
- `BlazeBooks/Engines/ReadingCoordinator.swift` - Extended with readingMode, highlightedWordIndex, switchMode(to:), commitWPMChange(), and page-mode-aware play()

## Decisions Made
- ReadingMode defaults to .rsvp to preserve existing behavior (RSVP was the primary mode through Phases 1-2)
- PageTextService is a struct (stateless service) rather than @Observable, following the WordTokenizer pattern
- ParagraphData caches WordToken arrays at chapter split time to avoid re-tokenization on every word highlight change (Research Pitfall 1)
- highlightedWordIndex returns nil when paused, avoiding "frozen highlight" in page mode (Research recommendation)
- setWPM refactored to only update RSVPEngine state during slider drag; commitWPMChange() handles deferred TTS stop/restart (Research Pitfall 5)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- xcodebuild required DEVELOPER_DIR override since active developer directory pointed to CommandLineTools instead of Xcode.app. Resolved by setting DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All service and engine code ready for Plan 02's view integration (PageModeView, WPMSliderView, ReadingView modifications)
- PageTextService provides the data layer that PageModeView needs to render highlighted paragraphs
- ReadingCoordinator's highlightedWordIndex and switchMode(to:) are ready for UI binding
- commitWPMChange() ready to wire to WPMSliderView's onEditingChanged callback
- No UI changes in this plan (pure engine/service layer)

## Self-Check: PASSED

All files verified present. All commits verified in git log.

---
*Phase: 03-reading-experience*
*Completed: 2026-02-20*
