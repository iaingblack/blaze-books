---
phase: 04-navigation-appearance
plan: 02
subsystem: ui
tags: [swiftui, appstorage, dark-mode, font-size, userdefaults, accessibility]

# Dependency graph
requires:
  - phase: 04-navigation-appearance/01
    provides: "TOC toolbar layout (topBarLeading), jumpToChapter shared navigation"
provides:
  - "ReadingDefaults enum with centralized font size constants and @AppStorage key"
  - "@AppStorage-persisted font size preference (12-32pt range, 2pt steps)"
  - "Font size +/- toolbar controls in ReadingView (topBarTrailing)"
  - "Dynamic font size applied to PageModeView and plain page mode paragraphs"
  - "Proportional line spacing (41% ratio) scaling with font size"
  - "Documented dark mode strategy: RSVP stays dark, chrome follows system"
affects: [05-library-management, 06-discovery]

# Tech tracking
tech-stack:
  added: []
  patterns: ["@AppStorage with centralized defaults enum to prevent inconsistent defaults across views", "Proportional line spacing ratio (font * 0.41) for scalable typography"]

key-files:
  created: []
  modified:
    - BlazeBooks/Views/Reading/ReadingView.swift
    - BlazeBooks/Views/Reading/PageModeView.swift
    - BlazeBooks/Views/Reading/RSVPDisplayView.swift

key-decisions:
  - "ReadingDefaults enum centralizes @AppStorage key and range constants to prevent default mismatches"
  - "Line spacing uses 41% ratio (readingFontSize * 0.41) preserving original 7/17 design proportion"
  - "RSVP dark theme is intentional design, not a dark mode bug -- documented in RSVPDisplayView"
  - "Idle state dash uses .white.opacity(0.3) instead of .secondary for consistent contrast on dark RSVP background"

patterns-established:
  - "Centralized defaults enum: Use an enum with static constants for @AppStorage keys and default values to prevent pitfall of inconsistent defaults across views"
  - "Proportional typography: Scale line spacing as a ratio of font size rather than fixed values"

requirements-completed: [APP-01, APP-02]

# Metrics
duration: 3min
completed: 2026-02-20
---

# Phase 4 Plan 2: Appearance & Font Size Summary

**@AppStorage-persisted font size controls (12-32pt) with proportional line spacing and documented RSVP dark theme strategy**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-20T22:08:28Z
- **Completed:** 2026-02-20T22:11:36Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- User-adjustable font size (12-32pt, 2pt steps) persisted via @AppStorage with centralized ReadingDefaults constants
- Font size +/- controls placed in ReadingView toolbar alongside existing TOC (leading) and mode toggle (principal)
- Dynamic font size applied to all three page mode rendering paths: PageModeView with TTS, PageModeView broken chapter, and plain page mode content
- Proportional line spacing (font * 0.41) maintains original reading comfort at any font size
- RSVP dark theme documented as intentional design choice; idle state contrast fixed for dark background
- Dark mode audit confirms all non-RSVP views use semantic SwiftUI colors (automatic dark/light adaptation)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add @AppStorage font size, font size controls, and apply dynamic font size to page mode views** - `eafe002` (feat)
2. **Task 2: Audit and document dark mode compatibility across reading views** - `eb6c1e8` (fix)

**Plan metadata:** `328ba34` (docs: complete plan)

## Files Created/Modified
- `BlazeBooks/Views/Reading/ReadingView.swift` - ReadingDefaults enum, @AppStorage font size, font size controls in toolbar, dynamic font in plain page mode, readingFontSize passed to PageModeView
- `BlazeBooks/Views/Reading/PageModeView.swift` - Added readingFontSize property, dynamic font and proportional line spacing on paragraph text
- `BlazeBooks/Views/Reading/RSVPDisplayView.swift` - Dark mode behavior documentation, idle state color fix (.white.opacity(0.3))

## Decisions Made
- **ReadingDefaults enum**: Centralizes fontSizeKey, default, min, max, and step to prevent @AppStorage default mismatches if multiple views ever reference the same key
- **41% line spacing ratio**: Original design used 7pt spacing at 17pt font (7/17 = 0.41); maintaining this ratio ensures comfortable reading at any font size
- **RSVP stays dark**: Documented as deliberate design following Spritz/RSVP reader conventions; not a dark mode bug
- **Idle dash color**: Changed from `.secondary.opacity(0.4)` to `.white.opacity(0.3)` because `.secondary` adapts to system appearance, producing unpredictable contrast on the always-black RSVP background

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 4 (Navigation & Appearance) is now complete: TOC navigation (04-01) and appearance/font size (04-02) both done
- All reading view features operational: RSVP, page mode, TTS, WPM control, chapter navigation, TOC, font sizing
- Ready for Phase 5 (Library Management) which depends on Phase 1 only

## Self-Check: PASSED

- All 3 modified files exist on disk
- Both task commits verified (eafe002, eb6c1e8)
- Build succeeds with 0 errors

---
*Phase: 04-navigation-appearance*
*Completed: 2026-02-20*
