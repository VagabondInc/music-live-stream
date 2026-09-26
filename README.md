# ASCII Broadcast

A native macOS / iPadOS / iOS studio that turns a playlist into a music-responsive ASCII
broadcast and streams it to YouTube Live.

A playlist goes in. The app analyses each track, writes a **visual score** for the whole
programme — chapters, scenes, transitions, titles, signal effects, memory marks — renders a
composed ASCII world that follows it, and sends 1080p30 H.264 + AAC over RTMPS while recording
locally.

![Studio](mocks/GUI%20Mockup.png)

---

## Repository layout

| Path | What it is |
| --- | --- |
| `PRODUCT MISSION/` | The mission the product is built from. |
| `docs/PHASE_1_ASCII_ANSI_VISUALIZATION_SPECIFICATION.md` | The visual engine specification: Visual DNA, analysis, scene families, layers, effects, transitions, titles, safety. |
| `docs/PHASE_2_PRODUCT_AND_TECHNICAL_SPECIFICATION.md` | Release boundary, rights model, broadcast state machine, module ownership, output ladder. |
| `docs/PHASE_3_MVP_IMPLEMENTATION_NOTES.md` | What this MVP actually implements, what is unvalidated, and what was deferred. **Read this before building.** |
| `apps/ASCIIBroadcast/` | The Swift/SwiftUI app. |
| `tools/generate_xcodeproj.py` | Regenerates the Xcode project deterministically. |
| `web/` | Marketing and preview page (static HTML/CSS/JS). |
| `mocks/GUI Mockup.png` | The authoritative GUI reference. |

---

## Building the app

```bash
python3 tools/generate_xcodeproj.py          # only needed if the project file is missing
open apps/ASCIIBroadcast/ASCIIBroadcast.xcodeproj
```

Requires Xcode 16, macOS 14 / iOS 17 SDKs. The project uses a file-system-synchronized root
group, so new source files are picked up without touching the pbxproj. Choose a signing team on
first build.

> **This source has not been compiled.** It was written on a machine without a Swift toolchain.
> Expect a first-build pass of small fixes; `docs/PHASE_3_MVP_IMPLEMENTATION_NOTES.md` §4 lists
> what to look at first.

### First run

No saved session? The studio loads a nine-track demo programme it synthesises itself (so it is
rights-cleared by construction), and offers to analyse it. After that you have a complete
channel — score, scenes, titles and all — without importing anything.

To rehearse the whole outbound pipeline without a network or a stream key, turn on **DRY RUN**
in the output panel: encoders, muxer, recorder and health all run against a simulated link.

---

## The parts

**Analysis** (`Analysis/`, `Audio/FeatureExtractor.swift`) — offline, on device. 24-band
spectral summaries at 2 Hz, tempo by autocorrelation over the onset envelope, section boundaries
by spectral novelty, letters assigned by self-similarity so a reprise is recognised as `A′`.

**Direction** (`Direction/`) — `ArtDirector` reads the whole programme and writes a seeded
`VisualDNA`: world, performance level, detail, colour behaviour, glyph profile, camera grammar,
family weights, motifs. `ScoreCompiler` turns DNA plus analysis into a `VisualScore`.

**Engine** (`Engine/`) — three authored scene families, a title layer, an effect system, ten
transition kinds, and a safety envelope that limits luminance flashes to three per second and
suppresses full-frame inversions when photosensitivity safeguards are on.

**Render** (`Render/`) — one authoritative program frame per interval, rasterised by batching
cells into a few dozen CoreText draws, shared by the SwiftUI preview and the encoder's pixel
buffers.

**Broadcast** (`Broadcast/`) — VideoToolbox H.264, `AVAudioConverter` AAC-LC at 44.1 kHz, FLV
tags, an RTMP/RTMPS client written on `NWConnection`, a simulated link, an `AVAssetWriter`
recorder, preflight, and a coordinator that keeps *what this machine is doing* and *what the
destination says* as two separate values.

---

## The marketing page

```bash
python3 -m http.server 8000 --directory web
```

Static, no build step, no dependencies. The ASCII in the hero and in the studio mock is rendered
live by `web/app.js` — a small imitation of the Folded City scene family, so the page previews
the product's grammar rather than showing a screenshot of it.

---

## Rights

You are responsible for the rights to the music you broadcast. The app records what you declare
about each track, shows it in preflight, and never declares anything on your behalf. Stream keys
are stored in the keychain and never written to the session document, exported presets,
diagnostics, or logs.
