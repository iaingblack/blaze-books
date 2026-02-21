# Phase 7: iCloud Sync - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Cross-device sync of the user's library, reading positions, and shelves via iCloud. Users can read on one device and continue seamlessly on another. EPUB files sync alongside metadata so books are available on all devices without re-importing.

</domain>

<decisions>
## Implementation Decisions

### Conflict resolution
- Most recent reading position wins (last-write-wins by timestamp)
- Shelf assignments use last-action-wins per book per shelf
- Deletion propagates to all devices (delete wins)
- All conflicts resolved silently -- never prompt or notify the user

### Sync scope
- EPUB files sync via iCloud alongside metadata (positions, shelves, book records)
- Gutenberg-downloaded books sync their EPUB files too (same as imported books)
- App settings (WPM, voice, font size) stay per-device and do NOT sync
- All books sync -- no limit, no user-controlled sync selection

### Sync behavior
- Claude's discretion on background vs on-app-open sync (whatever CloudKit supports naturally)
- Subtle sync indicator: small cloud icon or spinner in toolbar while syncing, disappears when done
- No iCloud account = app works normally with no error or prompt, sync just doesn't happen
- Sync works over any connection (Wi-Fi and cellular) -- no restrictions

### First-device experience
- All books download automatically on new device (not on-demand)
- Non-blocking: library shows immediately with whatever has synced, books become readable as they download
- Books not yet downloaded show a cloud badge on the cover (tap to prioritize download)
- Books with reading progress download first (prioritize continue-reading books)

### Claude's Discretion
- Background sync implementation (CloudKit push notifications vs polling vs on-foreground)
- CloudKit container and record type design
- Download queue management and retry logic
- Exact cloud badge icon design

</decisions>

<specifics>
## Specific Ideas

No specific requirements -- open to standard approaches. The key principle is that sync should be invisible and "just work" like Apple's own apps.

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 07-icloud-sync*
*Context gathered: 2026-02-21*
