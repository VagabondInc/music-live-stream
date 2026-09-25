# Vagabond // ASCII Broadcast — Browser MVP

This is a working, in-browser MVP of the product described in
[`../PRODUCT MISSION/# PRODUCT MISSION.md`](../PRODUCT%20MISSION/%23%20PRODUCT%20MISSION.md) and refined by
[`../docs/PHASE_1_ASCII_ANSI_VISUALIZATION_SPECIFICATION.md`](../docs/PHASE_1_ASCII_ANSI_VISUALIZATION_SPECIFICATION.md)
and [`../docs/PHASE_2_PRODUCT_AND_TECHNICAL_SPECIFICATION.md`](../docs/PHASE_2_PRODUCT_AND_TECHNICAL_SPECIFICATION.md).
Layout and information architecture follow [`../mocks/GUI Mockup.png`](../mocks/GUI%20Mockup.png) as the visual
reference. The final native product is iOS/iPadOS/macOS; this MVP demonstrates the product's *defining feature* — a
music-reactive ASCII/ANSI visual engine driving a broadcast-style control surface — using web technology so it can
run anywhere, including this sandbox's live preview.

## Run it

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # type-checks + production bundle
npm run lint
```

## What is real vs. simulated

**Real, functioning end-to-end:**

- **Single program audio bus.** One `AudioContext`, one analyser tap. Whatever is playing is exactly what is
  analyzed — never a different signal (Product Mission / Phase 2 §6).
- **Procedurally generated demo playlist.** Nine tracks are synthesized live with Web Audio oscillators/noise
  (kick, bass, arpeggio, riser), fully deterministic and license-free — no third-party recordings are bundled, so
  there is no rights ambiguity in the default demo (Phase 2 §2, "Onboarding" / "demo music" requirement).
- **Local file import.** Drag in your own audio files (Queue → Import). Each is decoded with
  `AudioContext.decodeAudioData`, played back through the same audio graph, and analyzed the same way procedural
  tracks are.
- **Real-time audio feature extraction**: RMS, bass/mid/high band energy, spectral centroid, spectral flux, and
  onset/transient detection — deterministic signal processing, no ML (per the Product Mission's explicit guidance).
- **Deterministic structure**: procedural tracks carry an *authored* section timeline (intro/verse/chorus/bridge/
  outro); imported files get an *estimated* structure derived from their real amplitude envelope, explicitly
  labeled "estimated" in the UI (Product Mission's "Music Intelligence" section: measured vs. inferred).
- **A modular, layered ASCII/ANSI scene system** with three distinct scene families/"Worlds" (Night Transit tunnel,
  Glass Cities parallax skyline, Data Void organic noise field + graph nodes), each with background, structural,
  reactive, particle/atmosphere, and typography layers, real camera drift, and three rotating transition techniques
  between tracks (dissolve / wipe / reconstruct) — not one visualizer with different palettes.
- **Guided art-direction controls** (World, Performance, Detail, Color, Glyph density, Motion, Glitch, Titles,
  Camera) that edit the live broadcast without interrupting playback.
- **Accessibility controls that affect the generated graphics themselves**: Reduce Motion and Photosensitivity Safe
  cap motion/flash/glitch in the renderer, not just the control chrome.
- **Now-playing title treatment** appears for the first/last ~10 seconds of each track, matching the Product
  Mission's readability-first metadata rule.
- **Session persistence**: Visual DNA and output profile (excluding secrets) persist across reloads via
  `localStorage`.

**Explicitly simulated (and labeled as such in the UI):**

- **RTMPS publishing to YouTube.** Browsers cannot open a raw RTMP/TLS socket or run a native H.264/AAC encoder —
  there is no such browser API. The Output panel implements the *exact state machine and language* from the Phase 2
  spec (`OFFLINE → PREVIEWING → PREFLIGHTING → CONNECTING → SENDING → RECONNECTING/ERROR`, plus a separate
  "destination visibility" concept distinguishing "sending" from a provider-confirmed live status), but no bytes
  ever leave the browser. This mirrors the Product Mission's error-design principle: never claim a viewer-visible
  live stream that hasn't been confirmed.
- **Preflight checks** run real checks where possible (audio loaded, analysis coverage, `navigator.onLine`,
  destination fields present, safety mode) and clearly label the encoder/network checks as simulated.
- **Stream health metrics** report a real, measured render FPS; bitrate/resolution reflect your selected output
  profile; dropped-frame/reconnect numbers are simulated for demonstration.

## Deliberately out of scope for this MVP

Per the Product Mission's own phasing and the Phase 2 roadmap, the following are not implemented here and are
called out in-app rather than faked: Apple Music/Spotify library integration, native AVFoundation/VideoToolbox
capture, an actual RTMPS publisher, multi-destination output, and rights/licensing verification. The Import tab
explicitly tells the user they are responsible for confirming rights before using an imported file live.

## Code map

```
src/audio/        AudioEngine (single program bus), procedural synth, track defs, structure estimation
src/visual/        GlyphGrid, palette, scenes/ (transit, cityscape, organism), renderer (compositing + transitions)
src/store.ts        Application state (zustand): playlist, transport, Visual DNA, output/broadcast state machine
src/components/     UI panels mirroring the GUI mockup regions
```
