# Screenshot Automation Process

## What we're doing
Capturing real simulator screenshots for each placeholder in `Documentation/website/index.html`,
then replacing the SVG placeholders with `<img>` tags pointing to the real screenshots.

## Branch
`automated-screenshots`

## Simulator
- Device: **iPhone 16e**, ID `B602DF06-2732-4AED-B7EF-108070231FA0`
- Take screenshot: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io B602DF06-2732-4AED-B7EF-108070231FA0 screenshot <path>.png`

## How automated clicks work
Clicks are sent by running shell scripts **inside Terminal.app** (which has Accessibility permission):
```bash
osascript -e 'tell application "Terminal" to do script "/tmp/script.sh"'
```
`cliclick` is used inside those scripts and inherits Terminal's Accessibility trust.

## Simulator window → macOS screen coordinate mapping
- Quartz window bounds: **X=555, Y=38, Width=402, Height=851**
- iPhone 16e logical screen: 390×844 pt
- Horizontal bezel: (402-390)/2 = 6 pt → content starts at screen X = **561**
- Vertical bezel: (851-844)/2 ≈ 3.5 pt → content starts at screen Y ≈ **42**
- Formula: `screen_x = 561 + ios_x`, `screen_y = 42 + ios_y`

## Confirmed working coordinates (iOS logical points)
| Element | iOS (x, y) | Screen (x, y) | Status |
|---|---|---|---|
| Great Gatsby book cover | (87, 200) | (648, 242) | ✅ opens book |
| Play/pause button | (195, 772) | (756, 814) | ✅ starts/stops RSVP |
| Long-press book | (87, 200) | (648, 242) | ✅ context menu |

## Still failing
| Element | iOS (x, y) tried | Notes |
|---|---|---|
| Page/RSVP segmented control | (155-163, 65-85) | Multiple attempts, never switches mode |
| TOC icon (☰) | (75, 75) | No effect observed |
| TTS toggle (speaker icon) | (42, 772) | Unknown - may work, screenshots didn't show change |

## Suspected issue with nav bar taps
Nav bar taps at ~y=65-85 do not register. Possible causes:
1. The segmented control Picker in SwiftUI nav bar principal has a different actual hit area
2. Coordinate offset is wrong — the Simulator window may have a title bar that shifts content down
3. While RSVP is playing, some touch lock may be in place
4. The nav bar chrome in `NavigationStack` responds differently to simulated clicks

## Screenshots captured (ready to use in HTML)
| File | Content | Quality |
|---|---|---|
| `library-view.png` | Library with 2 books | ✅ Good |
| `library-context-menu.png` | Long-press context menu | ✅ Good |
| `discover-tab.png` | Discover genre grid | ✅ Good |
| `discover-search.png` | Search results | ✅ Good |
| `discover-book-detail.png` | Book detail sheet | ✅ Good |
| `import-button.png` | Library with + button visible | ✅ Good |
| `rsvp-mode.png` | RSVP mode, word "The", ORP marker | ✅ Good |
| `page-mode.png` | Still shows RSVP — **needs retake** | ❌ Wrong |
| `tts-highlighting.png` | Still shows RSVP — **needs retake** | ❌ Wrong |
| `voice-picker.png` | Still shows RSVP — **needs retake** | ❌ Wrong |
| `wpm-slider.png` | Still shows RSVP — **needs retake** | ❌ Wrong |
| `table-of-contents.png` | Still shows RSVP — **needs retake** | ❌ Wrong |

## Next session TODO
1. **Debug nav bar tap issue** — try stopping RSVP first (tap pause), then switch mode
2. OR: use `xcrun simctl` URL scheme / XCTest to switch mode programmatically
3. Once in Page mode, capture: page-mode, tts-highlighting, voice-picker, wpm-slider, table-of-contents
4. **Update index.html** — replace all `<div class="screenshot">` SVG placeholders with `<img src="screenshots/xxx.png">`
5. Consider adding a speed-cap-banner screenshot (requires high WPM + TTS on a voice that caps)

## HTML placeholder → filename mapping
| HTML placeholder text | Target filename |
|---|---|
| Import button & file picker | `import-button.png` ✅ |
| Discover tab with genre grid | `discover-tab.png` ✅ |
| Library with Continue Reading strip and book grid | `library-view.png` ✅ |
| Long-press context menu | `library-context-menu.png` ✅ |
| Page mode reading view | `page-mode.png` ❌ needs retake |
| RSVP mode with single word | `rsvp-mode.png` ✅ |
| TTS enabled with word highlighting | `tts-highlighting.png` ❌ needs retake |
| Voice picker sheet | `voice-picker.png` ❌ needs retake |
| WPM slider | `wpm-slider.png` ❌ needs retake |
| Speed cap banner | `speed-cap-banner.png` ❌ not yet captured |
| Table of contents sheet | `table-of-contents.png` ❌ needs retake |
| Book detail sheet in Discover | `discover-book-detail.png` ✅ |
