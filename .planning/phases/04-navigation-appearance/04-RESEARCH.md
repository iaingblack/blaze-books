# Phase 4: Navigation & Appearance - Research

**Researched:** 2026-02-20
**Domain:** SwiftUI navigation (table of contents, chapter skip), appearance customization (dark mode, font size)
**Confidence:** HIGH

## Summary

Phase 4 adds four discrete features to the existing reading experience: a table of contents sheet for chapter jumping (NAV-02), chapter skip controls (NAV-03), system dark/light mode support (APP-01), and user-adjustable font size (APP-02). All four features use well-established SwiftUI APIs available on iOS 17.0 (the project's deployment target) and require no external dependencies.

The existing codebase already has partial chapter navigation implemented: `ReadingView.chapterNavigationBar` provides previous/next buttons, and `ReadingCoordinator.loadBook(chapterTexts:startChapter:startWord:)` handles chapter loading. NAV-03 is largely already working -- the existing chapter navigation bar at the bottom of ReadingView has previous/next buttons that call `navigateChapter(direction:)`. The main work is adding a table of contents sheet (NAV-02), ensuring dark mode compatibility (APP-01), and building a font size preference system (APP-02).

**Primary recommendation:** Use `@AppStorage` for persisting font size preference, a `.sheet` presentation for the table of contents list, pass `nil` to `preferredColorScheme` to follow the system setting (which is the default SwiftUI behavior), and propagate font size through SwiftUI's `@Environment` or direct binding from the `@AppStorage` value.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NAV-02 | User can navigate via table of contents to jump between chapters | Sheet-based chapter list view. Book model already has sorted chapters with titles and indices. Wire selection to existing `navigateChapter` logic. |
| NAV-03 | User can skip to next/previous chapter with controls | Already implemented in `ReadingView.chapterNavigationBar` with previous/next buttons. Verify completeness and polish. |
| APP-01 | App supports dark mode and light mode (follows system) | SwiftUI follows system appearance by default. Audit hardcoded colors (RSVP `Color.black` background, `.white` text). Do NOT call `preferredColorScheme()` -- just remove any appearance-forcing code. |
| APP-02 | User can adjust font size for reading | `@AppStorage("readingFontSize")` with stepper/buttons. Apply to PageModeView paragraph text and optionally RSVP display. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17.0+ | All UI (sheets, environment, AppStorage) | Project's existing UI framework; deployment target iOS 17.0 |
| Foundation | iOS 17.0+ | UserDefaults backing for @AppStorage | Automatic with SwiftUI |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @AppStorage | iOS 14+ | Persist font size preference to UserDefaults | Font size setting that survives app restarts |
| @Environment(\.colorScheme) | iOS 13+ | Detect current appearance for conditional styling | Adapting RSVP background/foreground to dark/light |
| .sheet | iOS 13+ | Present table of contents as modal | Chapter selection UI |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @AppStorage for font size | SwiftData model property | Over-engineered; font size is a simple key-value pref, not relational data. @AppStorage is the standard pattern. |
| Sheet for TOC | NavigationLink push | Sheet is better UX: user sees TOC overlay, selects chapter, sheet dismisses. Push navigation would lose the reading context. |
| Custom font size controls | Dynamic Type (.dynamicTypeSize) | Dynamic Type is system-wide and controlled in Settings. APP-02 specifically requires in-app adjustment, so custom controls are correct. |

## Architecture Patterns

### Recommended Project Structure

New files for this phase:

```
BlazeBooks/
├── Views/
│   └── Reading/
│       ├── TableOfContentsView.swift    # NEW: Chapter list sheet
│       ├── FontSizeControlView.swift    # NEW: Font size +/- controls (or inline in ReadingView)
│       ├── ReadingView.swift            # MODIFY: Add TOC button, font size, dark mode fixes
│       └── PageModeView.swift           # MODIFY: Accept dynamic font size parameter
│       └── RSVPDisplayView.swift        # MODIFY: Dark mode color adaptation
```

### Pattern 1: @AppStorage for User Preferences

**What:** Use `@AppStorage` property wrapper to persist simple user preferences (font size) to UserDefaults with automatic SwiftUI view invalidation.

**When to use:** Simple key-value preferences that need to persist across app launches and trigger view updates.

**Example:**
```swift
// Source: Apple Developer Documentation - AppStorage
// In any view that needs the font size:
@AppStorage("readingFontSize") private var readingFontSize: Double = 17.0

// Reading text uses the stored value:
Text(paragraph.text)
    .font(.system(size: readingFontSize))
    .lineSpacing(readingFontSize * 0.41)  // Scale line spacing proportionally
```

### Pattern 2: Sheet Presentation for Table of Contents

**What:** Present a chapter list as a `.sheet` with selection callback that dismisses and navigates.

**When to use:** Modal selection UI that overlays the current context.

**Example:**
```swift
// Source: SwiftUI standard pattern
struct TableOfContentsView: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onChapterSelected: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(chapters.sorted(by: { $0.index < $1.index }), id: \.id) { chapter in
                Button {
                    onChapterSelected(chapter.index)
                } label: {
                    HStack {
                        Text(chapter.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if chapter.index == currentChapterIndex {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Table of Contents")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

### Pattern 3: System Dark Mode (Default SwiftUI Behavior)

**What:** SwiftUI views automatically follow the system dark/light mode setting. No `preferredColorScheme()` call needed -- just avoid hardcoded colors.

**When to use:** APP-01 requirement (follow system).

**Key insight:** The app does NOT need to add dark mode support -- SwiftUI already does it. The work is *removing/fixing* hardcoded colors that break in one mode.

**Problem areas in existing code:**
```swift
// RSVPDisplayView.swift - HARDCODED black background:
Color.black  // Should adapt to dark/light mode

// RSVPDisplayView.swift - HARDCODED white text:
.foregroundStyle(.white)  // Should use .primary or adaptive color

// The RSVP view is deliberately dark for reading comfort.
// Decision needed: Keep RSVP always dark (reading-focused)
// OR adapt to system appearance.
```

### Pattern 4: Font Size Controls with Immediate Feedback

**What:** Stepper or +/- buttons that adjust a persisted font size value, applied immediately to reading text.

**When to use:** APP-02 requirement.

**Example:**
```swift
// Source: Standard iOS reading app pattern
HStack {
    Button {
        readingFontSize = max(12, readingFontSize - 2)
    } label: {
        Image(systemName: "textformat.size.smaller")
    }

    Text("\(Int(readingFontSize))pt")
        .font(.caption)
        .monospacedDigit()
        .frame(width: 40)

    Button {
        readingFontSize = min(32, readingFontSize + 2)
    } label: {
        Image(systemName: "textformat.size.larger")
    }
}
```

### Anti-Patterns to Avoid

- **Hardcoding Color.black/Color.white in views:** Use semantic colors (`.primary`, `.secondary`, `Color(.systemBackground)`) for dark mode compatibility. Exception: the RSVP view may intentionally use a dark background for reading comfort -- this is a deliberate design choice, not a bug.
- **Storing font size in SwiftData:** Font size is a display preference, not book/reading data. `@AppStorage` (UserDefaults) is the correct persistence layer for preferences.
- **Using Dynamic Type for the in-app font size control:** APP-02 asks for an in-app control, not reliance on system-wide Dynamic Type settings. Custom font size should work independently of the system Dynamic Type setting.
- **Re-implementing chapter navigation from scratch:** `ReadingView.navigateChapter(direction:)` already handles stopping playback, loading the new chapter, reloading the coordinator, and saving position. TOC selection should reuse this logic.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Persisting font size preference | Custom file I/O or SwiftData entity | `@AppStorage("readingFontSize")` | Built-in SwiftUI/UserDefaults integration with automatic view invalidation |
| Dark/light mode support | Custom color management system | SwiftUI semantic colors (`.primary`, `.secondary`, `Color(.systemBackground)`) | SwiftUI handles appearance switching automatically |
| Chapter list UI | Custom scroll view with buttons | SwiftUI `List` in a `.sheet` | List provides standard iOS table styling, haptics, accessibility for free |
| Chapter navigation logic | New navigation methods | Existing `navigateChapter(direction:)` with index parameter | Already handles stop/load/save cycle correctly |

**Key insight:** All four requirements in this phase use first-party SwiftUI APIs with no external dependencies. The complexity is in wiring and UI polish, not novel engineering.

## Common Pitfalls

### Pitfall 1: RSVP Dark Background vs System Dark Mode Conflict

**What goes wrong:** The RSVP view uses `Color.black` background and `.white`/`.primary` foreground. In dark mode, the system background is already near-black, so the RSVP view blends in. In light mode, the contrast between the black RSVP area and the white system chrome is intentional and helps focus.

**Why it happens:** RSVP reading apps traditionally use dark backgrounds to reduce eye strain during rapid word display. This conflicts with the expectation of "following system appearance."

**How to avoid:** Make a deliberate design decision: either (a) keep RSVP always dark (justified as a reading-focused display) and only adapt page mode / chrome to system appearance, or (b) create light and dark RSVP color schemes. Option (a) is simpler and follows the precedent set by Spritz and similar RSVP readers.

**Warning signs:** RSVP text becomes invisible (white on white in light mode, or dark on dark).

### Pitfall 2: Font Size Not Applied to All Text Locations

**What goes wrong:** Font size is applied to `PageModeView` paragraph text but forgotten in `ReadingView.chapterContent` (plain page mode), or line spacing is not scaled proportionally.

**Why it happens:** Font size appears in multiple places: `PageModeView.swift` line 59 (`.font(.system(size: 17))`), `ReadingView.swift` line 414 (`.font(.system(size: 17))`). Both must be updated.

**How to avoid:** Use the `@AppStorage` value consistently in both PageModeView and ReadingView's plain page mode content. Also scale `.lineSpacing()` proportionally (current value: 7pt at size 17, which is ~41% of font size).

**Warning signs:** Font size changes in one mode but not the other; text looks cramped or too spaced after resize.

### Pitfall 3: TOC Sheet Dismissal Without Navigation

**What goes wrong:** User taps a chapter in the TOC but the sheet dismissal animation blocks or races with the chapter loading.

**Why it happens:** SwiftUI sheet dismissal is animated and asynchronous. If chapter loading happens during dismissal, there can be visual glitches.

**How to avoid:** Dismiss the sheet first (set `showTOC = false`), then navigate on the next run loop or use `.onDismiss` callback to trigger navigation. Alternatively, dismiss and navigate in the same action -- SwiftUI handles this gracefully in iOS 17.

**Warning signs:** Sheet hangs, chapter doesn't load, or old chapter content flashes during transition.

### Pitfall 4: Chapter Navigation Breaks Playback State

**What goes wrong:** Jumping to a chapter via TOC while TTS/RSVP is playing causes stale state in the coordinator.

**Why it happens:** The existing `navigateChapter(direction:)` calls `coordinator.stop()` before loading. TOC navigation must do the same.

**How to avoid:** Reuse or extract the stop/load/save logic from `navigateChapter(direction:)` into a shared `jumpToChapter(index:)` method that the TOC callback and the prev/next buttons both call.

**Warning signs:** Audio continues playing from old chapter after jumping, or word index is wrong in new chapter.

### Pitfall 5: @AppStorage Default Value Inconsistency

**What goes wrong:** Different views declare `@AppStorage("readingFontSize")` with different default values, causing inconsistent initial state.

**Why it happens:** Each `@AppStorage` declaration specifies its own default. If one says `17.0` and another says `16.0`, the first view to access the key "wins."

**How to avoid:** Define the key name and default value as a constant, e.g.:
```swift
enum ReadingDefaults {
    static let fontSizeKey = "readingFontSize"
    static let defaultFontSize: Double = 17.0
}
```
Use this constant in every `@AppStorage` declaration.

**Warning signs:** Font size appears different on first launch vs after adjustment.

## Code Examples

Verified patterns from official sources:

### Table of Contents Sheet Integration in ReadingView

```swift
// In ReadingView:
@State private var showTableOfContents = false

// Add TOC button to toolbar or navigation bar:
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button {
            showTableOfContents = true
        } label: {
            Image(systemName: "list.bullet")
        }
    }
}
.sheet(isPresented: $showTableOfContents) {
    TableOfContentsView(
        chapters: sortedChapters,
        currentChapterIndex: currentChapterIndex,
        onChapterSelected: { chapterIndex in
            showTableOfContents = false
            jumpToChapter(chapterIndex)
        }
    )
    .presentationDetents([.medium, .large])
}
```

### Shared jumpToChapter Method (Refactored from navigateChapter)

```swift
// Extract chapter jump logic so both TOC and prev/next use it:
private func jumpToChapter(_ newIndex: Int) {
    guard newIndex >= 0, newIndex < totalChapters else { return }

    coordinator.stop()
    currentChapterIndex = newIndex
    loadChapter(at: newIndex)

    let chapterTexts = sortedChapters.map(\.text)
    coordinator.loadBook(
        chapterTexts: chapterTexts,
        startChapter: newIndex,
        startWord: 0
    )

    positionService.savePosition(
        book: book,
        chapterIndex: newIndex,
        scrollFraction: 0,
        chapterText: chapterText,
        modelContext: modelContext
    )
}

// navigateChapter becomes a thin wrapper:
private func navigateChapter(direction: Int) {
    jumpToChapter(currentChapterIndex + direction)
}
```

### Font Size with @AppStorage

```swift
// Source: Apple Developer Documentation - AppStorage
@AppStorage("readingFontSize") private var readingFontSize: Double = 17.0

// In page mode text:
Text(paragraph.text)
    .font(.system(size: readingFontSize))
    .lineSpacing(readingFontSize * 0.41)

// Font size control (compact, inline):
HStack(spacing: 16) {
    Button {
        readingFontSize = max(12, readingFontSize - 2)
    } label: {
        Image(systemName: "textformat.size.smaller")
            .font(.title3)
    }
    .disabled(readingFontSize <= 12)

    Text("\(Int(readingFontSize))")
        .font(.system(.body, design: .rounded).monospacedDigit())
        .frame(width: 30)

    Button {
        readingFontSize = min(32, readingFontSize + 2)
    } label: {
        Image(systemName: "textformat.size.larger")
            .font(.title3)
    }
    .disabled(readingFontSize >= 32)
}
```

### Dark Mode Color Adaptation for RSVP

```swift
// Source: Apple Developer Documentation - colorScheme environment
// Option A: Keep RSVP always dark (recommended for reading focus)
// No changes needed -- current Color.black + .white is intentional.
// Document this as a deliberate design decision.

// Option B: Adapt RSVP to system appearance
@Environment(\.colorScheme) private var colorScheme

var rsvpBackground: Color {
    colorScheme == .dark ? Color.black : Color(.systemGray6)
}

var rsvpTextColor: Color {
    colorScheme == .dark ? .white : .primary
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIKit UITableView for chapter lists | SwiftUI List in sheet | SwiftUI 1.0 (2019) | Simpler code, automatic styling |
| Manual UserDefaults read/write | @AppStorage property wrapper | iOS 14 / SwiftUI 2.0 (2020) | Automatic view invalidation on change |
| Explicit dark mode overrides | System-automatic with semantic colors | iOS 13+ | No code needed if using semantic colors |
| UIFontMetrics for dynamic sizing | @ScaledMetric / .dynamicTypeSize() | iOS 14+ / iOS 15+ | Not applicable here (we need in-app control, not system Dynamic Type) |

**Deprecated/outdated:**
- `UIApplication.shared.windows` for dark mode forcing -- replaced by Scene-based API in iOS 15+
- `overrideUserInterfaceStyle` on UIKit views -- not applicable in pure SwiftUI

## Open Questions

1. **RSVP View Dark Mode Strategy**
   - What we know: RSVP view currently uses hardcoded `Color.black` background and `.white` text. This is a deliberate design choice for reading focus, matching Spritz-style readers.
   - What's unclear: Should RSVP adapt to system light mode (lighter background) or stay permanently dark?
   - Recommendation: Keep RSVP always dark. The black background is functional (reduces eye strain during rapid word display) and matches user expectations from speed-reading tools. Only the chrome (navigation bars, controls) should follow system appearance. If the user/planner disagrees, Option B (adaptive) is straightforward to implement.

2. **Font Size Range Bounds**
   - What we know: Current font size is 17pt. Apple Books allows roughly 12pt to 28pt. Kindle goes wider.
   - What's unclear: Exact min/max bounds for comfortable reading in this app.
   - Recommendation: Use 12pt minimum, 32pt maximum, 2pt step. The 12-32 range covers small text for power readers to large text for accessibility. This can be tuned later without architectural changes.

3. **Font Size Applied to RSVP Mode?**
   - What we know: RSVP display uses 36pt monospaced font for ORP alignment. Changing this size would require recalculating `characterWidth` (currently hardcoded to 21.6).
   - What's unclear: Whether APP-02 "font size for reading" means page mode only or both modes.
   - Recommendation: Apply font size only to page mode text. RSVP font size is a display engine concern with ORP alignment constraints -- changing it introduces complexity with minimal user benefit. If desired later, it can be added as a separate "RSVP font size" control.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `preferredColorScheme(_:)` -- https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:)
- Apple Developer Documentation: `AppStorage` -- https://developer.apple.com/documentation/swiftui/appstorage
- Apple Developer Documentation: `DynamicTypeSize` -- https://developer.apple.com/documentation/swiftui/dynamictypesize
- Apple Developer Documentation: `colorScheme` environment -- https://developer.apple.com/documentation/swiftui/environmentvalues/colorscheme
- Context7 `/websites/developer_apple_swiftui` -- preferredColorScheme, AppStorage, dynamicTypeSize, font sizing

### Secondary (MEDIUM confidence)
- Existing codebase analysis: ReadingView.swift, ReadingCoordinator.swift, RSVPDisplayView.swift, PageModeView.swift -- verified chapter navigation, font usage, color hardcoding
- Xcode project.pbxproj -- confirmed IPHONEOS_DEPLOYMENT_TARGET = 17.0

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all APIs are first-party SwiftUI, well-documented, used since iOS 14+
- Architecture: HIGH -- patterns follow standard SwiftUI idioms (sheets, @AppStorage, semantic colors); existing codebase already has 80% of the navigation infrastructure
- Pitfalls: HIGH -- pitfalls are based on direct code inspection of hardcoded values and known SwiftUI sheet behavior

**Research date:** 2026-02-20
**Valid until:** 2026-04-20 (stable -- SwiftUI APIs are mature and unlikely to change)
