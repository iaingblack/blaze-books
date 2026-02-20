---
phase: 02-reading-engine
plan: 03
subsystem: reading-ui
tags: [rsvp-display, orp-highlighting, voice-picker, speed-cap-banner, swiftui, reading-view, dual-mode, environment-object]

# Dependency graph
requires:
  - phase: 02-reading-engine-02
    provides: "ReadingCoordinator, SpeedCapService, VoiceManager for UI binding"
  - phase: 02-reading-engine-01
    provides: "RSVPEngine and TTSService driving word advancement and speech"
provides:
  - "RSVPDisplayView: ORP-aligned single word display with accent-highlighted recognition point"
  - "VoicePickerView: In-reader voice selection sheet with preview and download guidance"
  - "SpeedCapBanner: Inline non-disruptive speed cap notification"
  - "ReadingView: Dual-mode reading (Page scroll + RSVP) with play/pause, TTS toggle, WPM control"
  - "BlazeBooksApp: Phase 2 service injection (ReadingCoordinator, SpeedCapService, VoiceManager)"
affects: [phase-3, phase-4]

# Tech tracking
tech-stack:
  added: []
  patterns: [GeometryReader ORP centering, monospaced font for character-width consistency, .transaction animation suppression for instant word swap, segmented Picker for mode switching, environment object injection chain]

key-files:
  created:
    - BlazeBooks/Views/Reading/RSVPDisplayView.swift
    - BlazeBooks/Views/Reading/VoicePickerView.swift
    - BlazeBooks/Views/Reading/SpeedCapBanner.swift
  modified:
    - BlazeBooks/Views/Reading/ReadingView.swift
    - BlazeBooks/App/BlazeBooksApp.swift

key-decisions:
  - "White foreground for RSVP before/after ORP text on dark background (bug fix: .primary was invisible on black)"
  - "GeometryReader with half-width frames for ORP character centering at exact screen midpoint"
  - "Segmented Picker for Page/RSVP mode switching in the reading view toolbar"

patterns-established:
  - "ORP centering pattern: HStack with fixed-width left/right frames computed from GeometryReader, ORP character at center"
  - "Environment object injection chain: BlazeBooksApp creates services, injects via .environment(), views observe via @Environment"
  - "Dual-mode view pattern: segmented control toggles visibility of scroll view vs RSVP overlay"

requirements-completed: [READ-01, TTS-01, TTS-03, TTS-04, TTS-05]

# Metrics
duration: multi-session
completed: 2026-02-20
---

# Phase 2 Plan 03: Reading Views Summary

**RSVP display with ORP-centered word highlighting, voice picker sheet, speed cap banner, and dual-mode ReadingView integration with full Phase 2 service injection**

## Performance

- **Duration:** Multi-session (checkpoint verification)
- **Started:** 2026-02-20
- **Completed:** 2026-02-20
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 5

## Accomplishments
- RSVPDisplayView renders ORP-aligned words with the recognition point character accent-highlighted at exact screen center using GeometryReader-computed frame widths and monospaced font
- VoicePickerView presents installed English voices sorted by quality tier with tap-to-select, speaker-icon preview, and download guidance card with Settings deep-link
- SpeedCapBanner provides inline non-disruptive yellow notification when WPM exceeds the current voice's capability
- ReadingView supports dual-mode operation: existing Page scroll mode alongside new RSVP mode with play/pause, TTS toggle, WPM slider, voice picker, and progress tracking
- BlazeBooksApp creates and injects all Phase 2 services (ReadingCoordinator, SpeedCapService, VoiceManager) as environment objects

## Task Commits

Each task was committed atomically:

1. **Task 1: Create RSVPDisplayView, VoicePickerView, and SpeedCapBanner** - `0804795` (feat)
2. **Task 2: Integrate RSVP mode into ReadingView and wire coordinator through BlazeBooksApp** - `01c3406` (feat)
3. **Task 3: Verify Phase 2 reading engine end-to-end** - `39dab3f` (fix: bug found during verification)

## Files Created/Modified
- `BlazeBooks/Views/Reading/RSVPDisplayView.swift` - ORP-aligned single word display with three-segment HStack (beforeORP, ORP character in accent, afterORP), vertical guide line, dark background, animation-suppressed instant word swap
- `BlazeBooks/Views/Reading/VoicePickerView.swift` - NavigationStack with Installed voices list (checkmark selection, speaker preview) and Available for Download guidance card with Settings deep-link button
- `BlazeBooks/Views/Reading/SpeedCapBanner.swift` - Inline yellow/orange banner with info icon, slide+opacity transition, conditionally visible when speed is capped
- `BlazeBooks/Views/Reading/ReadingView.swift` - Added RSVP mode with segmented Page/RSVP picker, RSVPDisplayView integration, play/pause/TTS controls, WPM slider, voice picker sheet, SpeedCapBanner, progress indicators
- `BlazeBooks/App/BlazeBooksApp.swift` - Creates ReadingCoordinator, SpeedCapService, VoiceManager and injects as environment objects alongside existing Phase 1 services

## Decisions Made
- Used `.foregroundStyle(.white)` instead of `.foregroundStyle(.primary)` for RSVP text segments on dark background -- `.primary` adapts to system appearance and was invisible on the black RSVP background (discovered during human verification)
- GeometryReader computes frame widths for ORP centering: left frame = viewWidth/2 - charWidth/2, right frame mirrors, keeping the ORP character at exact screen center
- Segmented Picker for mode switching (Page vs RSVP) placed in the reading view, toggling between scroll content and RSVP overlay

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed invisible RSVP text foreground color**
- **Found during:** Task 3 (human verification checkpoint)
- **Issue:** RSVPDisplayView used `.foregroundStyle(.primary)` for beforeORP and afterORP text segments, which resolved to black on the dark RSVP background, making text invisible
- **Fix:** Changed both instances to `.foregroundStyle(.white)` for proper contrast on dark background
- **Files modified:** BlazeBooks/Views/Reading/RSVPDisplayView.swift
- **Verification:** Human verified text is now visible and readable
- **Committed in:** 39dab3f

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor color fix for dark background visibility. No scope creep.

## Issues Encountered
None beyond the foreground color bug caught during verification. All three view files compiled cleanly on first build. Integration with ReadingView and BlazeBooksApp required no additional changes to Phase 2 engine code.

## User Setup Required

None - no external service configuration required. All components use Apple frameworks (AVFoundation, SwiftUI) already available in the project.

## Next Phase Readiness
- Phase 2 complete: all reading engine components built and verified end-to-end
- Phase 3 (Reading Experience) can build on the dual-mode ReadingView to add page-mode TTS word highlighting and mode switching with position preservation
- ReadingCoordinator's observable state (currentWord, isPlaying, currentWPM, effectiveWPM, isSpeedCapped, speedCapMessage) is fully wired to SwiftUI views
- VoiceManager and SpeedCapService are injected as environment objects, available to any view in the hierarchy

## Self-Check: PASSED

All 5 files verified on disk (RSVPDisplayView.swift, VoicePickerView.swift, SpeedCapBanner.swift, ReadingView.swift, BlazeBooksApp.swift). All 3 task commits (0804795, 01c3406, 39dab3f) verified in git history.

---
*Phase: 02-reading-engine*
*Completed: 2026-02-20*
