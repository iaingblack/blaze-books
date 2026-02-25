# Changelog

All notable changes to BlazeBooks will be documented in this file.

## [1.0.1] - 2026-02-25

### Fixed
- Tip Jar sheet ("Show Your Support") no longer shows an infinite loading spinner when the in-app purchase product cannot be loaded from the App Store
- StoreKit product loading now uses proper error handling instead of silently swallowing failures with `try?`

### Details
- Added `loadFailed` state to `TipJarService` to track when product loading fails
- `TipJarSheet` now shows "Tips are not available right now." with a Done button on failure, instead of spinning forever
- This was flagged by App Store Review (Guideline 2.1 - App Completeness) on iPad Air 11-inch (M3) and iPhone 17 Pro Max
