---
phase: 02-reading-engine
plan: 02
subsystem: reading-engine
tags: [coordinator, state-machine, tts, rsvp, speed-cap, voice-manager, observable, avspeechsynthesisvoice, userdefaults]

# Dependency graph
requires:
  - phase: 02-reading-engine-01
    provides: "RSVPEngine (Timer-driven word advancement) and TTSService (sentence-level AVSpeechSynthesizer)"
provides:
  - "ReadingCoordinator: Central state machine orchestrating RSVP and TTS with dual-mode operation"
  - "SpeedCapService: Per-voice WPM calibration with rate conversion and capping"
  - "VoiceManager: Voice enumeration, preview, Settings deep-link, and change observation"
affects: [02-03, phase-3]

# Tech tracking
tech-stack:
  added: []
  patterns: [withObservationTracking bridge for RSVPEngine state sync, Task.sleep for chapter auto-advance delay, UserDefaults voice persistence, NotificationCenter voice change observation, Settings deep-link via App-prefs URL scheme]

key-files:
  created:
    - BlazeBooks/Engines/ReadingCoordinator.swift
    - BlazeBooks/Services/SpeedCapService.swift
    - BlazeBooks/Services/VoiceManager.swift
  modified:
    - BlazeBooks/Engines/TTSService.swift

key-decisions:
  - "withObservationTracking for RSVPEngine -> ReadingCoordinator state bridge in Timer mode (recursive observation pattern)"
  - "1.5-second chapter auto-advance delay via Task.sleep (within Claude's discretion for chapter transition duration)"
  - "WPM-to-rate linear interpolation: rate 0.5 = 180 WPM baseline, clamped to AVSpeechUtterance min/max range"
  - "Conservative per-voice caps by quality tier: 300 WPM default, 350 enhanced, 400 premium"
  - "Download guidance card instead of 'Available for Download' section (Apple provides no API for uninstalled voices)"
  - "Voice preview uses 'The quick brown fox jumps over the lazy dog.' sample phrase"

patterns-established:
  - "Dual-mode coordinator: central state machine delegates to mode-specific engines via callbacks"
  - "withObservationTracking recursive pattern: re-registers observation on each change for continuous sync"
  - "UserDefaults persistence for user preferences (voice selection) with fallback to defaults"
  - "NotificationCenter observation with weak self capture for lifecycle-safe notification handling"

requirements-completed: [TTS-01, TTS-03, TTS-04, TTS-05]

# Metrics
duration: 5min
completed: 2026-02-20
---

# Phase 2 Plan 02: Coordination and Services Summary

**ReadingCoordinator dual-mode state machine with SpeedCapService per-voice WPM capping and VoiceManager English voice enumeration with Settings deep-link**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-20T19:28:49Z
- **Completed:** 2026-02-20T19:34:10Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- ReadingCoordinator orchestrates RSVPEngine and TTSService with seamless dual-mode switching: TTS drives word advancement when active, Timer drives exact WPM when TTS is off
- SpeedCapService provides per-voice WPM capping with quality-tier defaults and WPM-to-AVSpeechUtterance rate conversion
- VoiceManager enumerates installed English voices with quality-tier sorting, voice preview, Settings deep-link for downloads, and notification-based auto-refresh

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ReadingCoordinator with dual-mode operation** - `4b3b73a` (feat)
2. **Task 2: Create SpeedCapService and VoiceManager** - `ea112b0` (feat)

## Files Created/Modified
- `BlazeBooks/Engines/ReadingCoordinator.swift` - @Observable central state machine with Timer/TTS mode switching, pause/resume with 4-word backup, chapter auto-advance, speed cap integration
- `BlazeBooks/Services/SpeedCapService.swift` - Per-voice WPM capping with quality-tier defaults (300/350/400), WPM-to-rate linear conversion, cap cache for empirical calibration
- `BlazeBooks/Services/VoiceManager.swift` - English voice enumeration via AVSpeechSynthesisVoice.speechVoices(), quality sorting, preview synthesizer, Settings deep-link, notification observation
- `BlazeBooks/Engines/TTSService.swift` - Added currentVoiceIdentifier public read-only accessor (needed by ReadingCoordinator for speed cap queries)

## Decisions Made
- Used withObservationTracking recursive pattern to bridge RSVPEngine's @Observable state changes to ReadingCoordinator in Timer mode -- re-registers observation after each change
- Chapter auto-advance uses 1.5-second delay via Task.sleep (within Claude's discretion range for chapter transitions)
- WPM-to-rate conversion uses linear interpolation with rate 0.5 = 180 WPM baseline, acknowledging this is approximate and can be refined empirically
- Conservative per-voice speed caps by quality tier (300/350/400 WPM) as starting estimates pending empirical calibration
- Download guidance card approach for "Available for Download" section since Apple provides no API to enumerate uninstalled voices
- Voice preview uses "The quick brown fox jumps over the lazy dog." as sample phrase (Claude's discretion)
- Selected voice persisted to UserDefaults with key "BlazeBooks.selectedVoiceIdentifier" for cross-launch persistence

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added currentVoiceIdentifier accessor to TTSService**
- **Found during:** Task 1 (ReadingCoordinator implementation)
- **Issue:** ReadingCoordinator needs to read the current voice identifier from TTSService to query SpeedCapService, but TTSService only had private `selectedVoiceIdentifier`
- **Fix:** Added `var currentVoiceIdentifier: String? { selectedVoiceIdentifier }` public read-only computed property to TTSService
- **Files modified:** BlazeBooks/Engines/TTSService.swift
- **Verification:** Clean build succeeds with coordinator accessing the property
- **Committed in:** 4b3b73a (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minimal API surface addition to TTSService. Required for coordinator to function. No scope creep.

## Issues Encountered
None -- all three files compiled cleanly together on first build attempt. The only issue was the missing TTSService accessor, caught during implementation and resolved immediately.

## User Setup Required

None - no external service configuration required. All components use Apple frameworks already available in the project.

## Next Phase Readiness
- ReadingCoordinator is ready for Plan 03 (Reading Views) to observe and drive SwiftUI reading UI
- ReadingCoordinator exposes all observable state needed for reading view: currentWord, isPlaying, currentWPM, effectiveWPM, isSpeedCapped, speedCapMessage, progress tracking
- VoiceManager provides the data model for the voice picker UI in Phase 3
- SpeedCapService integrates with coordinator for inline speed cap banner display
- All CONTEXT.md locked decisions are implemented and enforced at the coordinator level

## Self-Check: PASSED

All 3 created files verified on disk. TTSService modification verified. Both task commits (4b3b73a, ea112b0) verified in git history. Clean build succeeds with zero errors and zero warnings.

---
*Phase: 02-reading-engine*
*Completed: 2026-02-20*
