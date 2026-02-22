# Screenshot Automation Process

## Current state
7 screenshots are live in `index.html`. Still needed (no placeholder in HTML, just missing content):
- `page-mode.png`, `tts-highlighting.png`, `voice-picker.png`, `wpm-slider.png`, `table-of-contents.png`

## Branch
`automated-screenshots`

## Simulator
- Device: **iPhone 16e**, ID `B602DF06-2732-4AED-B7EF-108070231FA0`
- Take screenshot: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io B602DF06-2732-4AED-B7EF-108070231FA0 screenshot <path>.png`

## How automated clicks work
Clicks are sent by running shell scripts **inside Terminal.app** (which has Accessibility permission):
```bash
osascript -e 'tell application "Terminal" to do script "..." in window 1'
```
Use `in window 1` to run in an **existing** Terminal window. Opening a new window can cover the Simulator.

## CRITICAL: cliclick syntax
- `cliclick c:x,y` — **LEFT CLICK** at screen coordinates ✅
- `cliclick t:text` — **TYPES TEXT** (not a click!) ❌ was the cause of many hours of lost effort
- `cliclick kp:esc` — press Escape key
- `cliclick p` — print current mouse position (useful for debugging)

## CRITICAL: Activate Simulator before clicking
The Simulator sits **behind VSCode/Cursor**. Without activation, clicks go to the wrong window:
```bash
osascript -e 'tell application "Simulator" to activate' 2>/dev/null
sleep 0.4
cliclick c:648,242
```

## CRITICAL: Don't use these inside Terminal scripts
- `screencapture` — triggers macOS Screen Recording permission dialog, blocks Simulator
- `tell application "System Events"` — triggers System Events permission dialog
- Only use `xcrun simctl io <id> screenshot <path>` for capturing iOS screenshots from scripts

## Simulator window → macOS screen coordinate mapping
- Quartz window bounds: **X=555, Y=38, Width=402, Height=851**
- iPhone 16e logical screen: 390×844 pt
- Formula: `screen_x = 561 + ios_x`, `screen_y = 42 + ios_y`

## Confirmed working coordinates (iOS logical points)
| Element | iOS (x, y) | Screen (x, y) | Notes |
|---|---|---|---|
| Great Gatsby book cover | (87, 200) | (648, 242) | opens book |
| Play/pause button | (195, 772) | (756, 814) | starts/stops RSVP |
| Long-press book | (87, 200) | (648, 242) | hold for context menu |

## Nav bar coordinates (not yet confirmed working)
| Element | iOS (x, y) | Screen (x, y) |
|---|---|---|
| TOC icon (list.bullet) | (87, 72) | (648, 114) |
| Page mode button | (143, 72) | (704, 114) |
| RSVP mode button | (223, 72) | (784, 114) |

These have never been confirmed because all previous attempts used the wrong `t:` syntax instead of `c:`.
With the correct `c:x,y` syntax and Simulator activated first, these should work.

## ReadingView controls bar layout (for coordinate reference)
```
HStack(spacing: 20) padding(.horizontal, 20):
  TTS toggle    frame(44,44)  ios x ≈ 42
  Voice picker  frame(44,44)  ios x ≈ 94
  Punctuation   frame(44,44)  ios x ≈ 146
  [Spacer]
  Play/Pause    ~50pt icon    ios x ≈ 195  (center of 390pt screen)
  [Spacer]
  WPM button    frame(70,44)  ios x ≈ 291
  Clear (44pt)               ios x ≈ 349
All at ios y ≈ 772
```

## Screenshots in use (index.html)
| File | Content |
|---|---|
| `library-view.png` | Library with 2 books |
| `library-context-menu.png` | Long-press context menu |
| `discover-tab.png` | Discover genre grid |
| `discover-search.png` | Search results |
| `discover-book-detail.png` | Book detail sheet |
| `import-button.png` | Library with + button visible |
| `rsvp-mode.png` | RSVP mode, word with ORP marker |

## Still needed (no placeholder currently — add back to HTML when captured)
| File | Where in HTML |
|---|---|
| `page-mode.png` | Reading Modes → Page Mode section |
| `tts-highlighting.png` | Text-to-Speech section |
| `voice-picker.png` | Text-to-Speech → Choosing a Voice |
| `wpm-slider.png` | Speed Controls → WPM Slider |
| `table-of-contents.png` | Navigation → Table of Contents |
