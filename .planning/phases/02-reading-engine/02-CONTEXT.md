# Phase 2: Reading Engine - Context

**Gathered:** 2026-02-20
**Status:** Ready for planning

<domain>
## Phase Boundary

The synchronization engine that keeps TTS audio locked to visual word display. Delivers RSVP timing with ORP positioning, AVSpeechSynthesizer integration, voice selection and download management, and graceful speed capping. Reading views and mode switching are Phase 3.

</domain>

<decisions>
## Implementation Decisions

### RSVP word display
- ORP-aligned (Spritz-style) positioning — the Optimal Recognition Point letter is always at screen center to reduce eye movement
- ORP letter highlighted with a distinct accent color; rest of word in neutral color
- Natural punctuation pauses — short pause at commas, longer at periods and paragraph breaks (not strict metronomic timing)
- When idle/paused: last word stays frozen on screen with a play button overlay — clear resume point

### TTS-RSVP sync model
- TTS drives everything — speech synthesis dictates when the next word appears on screen, WPM becomes approximate when TTS is active
- When TTS is off, WPM timer drives RSVP at exact configured speed
- On resume after pause: back up ~3-5 words before the pause point to help user regain context
- At chapter boundaries: auto-advance with a brief pause, then start the next chapter automatically — uninterrupted listening

### Voice selection UX
- Voice picker accessible from within the reading view (in-reader settings), not a separate app settings screen
- Tap a voice to hear a short fixed sample phrase — quick comparison between voices
- Two sections: "Installed" at top, "Available for Download" below — clear separation with download affordance
- Flat list of English voices only for v1 — no language/accent grouping

### Speed cap behavior
- Per-voice speed cap — each voice has its own natural maximum WPM; faster voices allow higher speeds
- When WPM exceeds voice capability: inline banner in reading view ("Voice capped at X WPM") — non-disruptive, stays visible
- Slider snaps to actual capped WPM — shows reality rather than preserving the user's requested-but-unachievable speed
- Silent RSVP (no TTS) capped at slider max of 500 WPM — consistent limits regardless of mode

### Claude's Discretion
- Whether RSVP can run without TTS (silent mode) or always implies audio — decide based on what feels right for the UX
- Exact ORP calculation algorithm (letter position within word)
- Punctuation pause durations (exact milliseconds for comma vs period vs paragraph)
- Sample phrase used for voice preview
- Exact resume backup word count (3-5 range)
- Chapter auto-advance pause duration

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-reading-engine*
*Context gathered: 2026-02-20*
