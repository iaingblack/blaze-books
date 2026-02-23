# Check iOS Submission — Implementation Plan

## Context
Codebase scan identified security vulnerabilities and App Store compliance issues. This plan addresses 8 confirmed issues across 11 files. Three additional findings were validated as **false positives** and require no action.

---

## Fixes (ordered by priority)

### Fix 1: Remove force unwrap on app startup
**File:** `BlazeBooks/App/BlazeBooksApp.swift:46`
- Replace `try!` with `do/catch` wrapping the in-memory `ModelContainer`
- Inner catch uses `fatalError` with error description (in-memory store cannot fail in practice, but removes the `try!` that static analysis flags)

### Fix 2: Add "Restore Purchases" button
**Files:** `BlazeBooks/Services/TipJarService.swift`, `BlazeBooks/Views/Library/TipJarSheet.swift`
- Add `restorePurchases()` method to TipJarService that calls `AppStore.sync()` then re-checks entitlements
- Add "Restore Purchases" text button below the purchase button in TipJarSheet (only shown in non-purchased state)
- Required by App Store guideline 3.1.1 for non-consumable IAPs

### Fix 3: Replace private Settings URL scheme
**Files:** `BlazeBooks/Services/VoiceManager.swift:127-135`, `BlazeBooks/Views/Reading/VoicePickerView.swift`
- Replace `App-Prefs:ACCESSIBILITY` (private, causes rejections) with `UIApplication.openSettingsURLString` (public)
- Update button label from "Open Accessibility Settings" to "Open Settings"
- VoicePickerView already has text instructions guiding users to the right place in Settings

### Fix 4: URL domain allowlisting
**New file:** `BlazeBooks/Utilities/URLValidator.swift`
**Modified:** `BlazeBooks/Services/BookDownloadService.swift:61`, `BlazeBooks/Services/GutendexService.swift:~144`, `BlazeBooks/Services/GutenbergOPDSService.swift:~69`
- Create `URLValidator` enum with `isAllowed(_:)` and `validated(_:)` methods
- Allowlist: `gutendex.com`, `www.gutenberg.org` — HTTPS only
- Apply before downloads in BookDownloadService and before pagination fetches in both Gutendex and OPDS services

### Fix 5: EPUB file size limit (100MB)
**Files:** `BlazeBooks/Services/EPUBImportService.swift:286`, `BlazeBooks/Services/BookDownloadService.swift:61`
- Check file size via `FileManager.attributesOfItem` before `Data(contentsOf:)` in EPUBImportService
- Check downloaded file size before processing in BookDownloadService
- Cap at 100MB, throw/show user-facing error if exceeded

### Fix 6: Path traversal defense in FileStorageManager
**File:** `BlazeBooks/Utilities/FileStorageManager.swift:24`
- Add `sanitizeFileName()` that extracts `lastPathComponent` and rejects `..`/`.`/empty
- Apply in `localURL(for:)` so all callers benefit
- Add prefix check in `deleteFile()` to verify resolved path stays within `booksDirectory`

### Fix 7: XML parser XXE hardening
**File:** `BlazeBooks/Services/GutenbergOPDSService.swift:~128`
- Add `parser.shouldResolveExternalEntities = false` after creating XMLParser
- One line, defense in depth (Foundation defaults to false but explicit is better)

### Fix 8: File protection on downloaded EPUBs
**File:** `BlazeBooks/Services/BookDownloadService.swift:~72`
- Add `FileProtectionType.complete` attribute after `moveItem` call
- Use `try?` so it doesn't block downloads if attribute setting fails

---

## Files changed summary

| File | Fixes |
|------|-------|
| `BlazeBooks/App/BlazeBooksApp.swift` | #1 |
| `BlazeBooks/Services/TipJarService.swift` | #2 |
| `BlazeBooks/Views/Library/TipJarSheet.swift` | #2 |
| `BlazeBooks/Services/VoiceManager.swift` | #3 |
| `BlazeBooks/Views/Reading/VoicePickerView.swift` | #3 |
| `BlazeBooks/Utilities/URLValidator.swift` | #4 (new) |
| `BlazeBooks/Services/BookDownloadService.swift` | #4, #5, #8 |
| `BlazeBooks/Services/GutendexService.swift` | #4 |
| `BlazeBooks/Services/GutenbergOPDSService.swift` | #4, #7 |
| `BlazeBooks/Services/EPUBImportService.swift` | #5 |
| `BlazeBooks/Utilities/FileStorageManager.swift` | #6 |

---

## Validated false positives (no action needed)

- **Release signing identity "Apple Development"** — `CODE_SIGN_STYLE = Automatic` on both configs, Xcode handles distribution cert at export
- **aps-environment = development** — automatic signing adjusts to production during App Store export
- **remote-notification without push code** — justified by CloudKit sync via SwiftData (silent push is automatic)

---

## Verification

1. Build in Xcode — confirm zero warnings/errors
2. Run on simulator — confirm app launches, Discover search works, book download works
3. Test TipJarSheet — confirm "Restore Purchases" button appears below purchase button
4. Test VoiceManager — confirm "Open Settings" button opens Settings (not Accessibility directly)
5. Verify in BookDownloadService that a book from Gutenberg still downloads successfully (URL passes allowlist)
