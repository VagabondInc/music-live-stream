# Phase 3 — MVP Implementation Notes

**Status:** source complete, not yet compiled.
**Target:** `apps/ASCIIBroadcast` — one Swift/SwiftUI target for macOS 14, iPadOS 17 and iOS 17.
**Written against:** `PRODUCT MISSION`, `docs/PHASE_1_ASCII_ANSI_VISUALIZATION_SPECIFICATION.md`,
`docs/PHASE_2_PRODUCT_AND_TECHNICAL_SPECIFICATION.md`, and `mocks/GUI Mockup.png`.

These notes say what was built, what was deliberately deferred, and — importantly — what has
not been executed yet. The development environment for this pass had no Swift toolchain, so
**nothing here has been compiled or run.** Treat the first build on a Mac as the acceptance
gate, not as a formality.

---

## 1. How to build

```bash
open apps/ASCIIBroadcast/ASCIIBroadcast.xcodeproj
# or
xcodebuild -project apps/ASCIIBroadcast/ASCIIBroadcast.xcodeproj -scheme ASCIIBroadcast -destination 'platform=macOS' build
```

The project is generated, not hand-maintained:

```bash
python3 tools/generate_xcodeproj.py
```

It writes `project.pbxproj` with Xcode 16's **file-system-synchronized root group**
(`objectVersion = 77`), so every file added under `apps/ASCIIBroadcast/ASCIIBroadcast/` is
compiled automatically and the pbxproj never needs editing. Signing is left unset: pick a team
in Xcode on first build. There is no app icon set yet — only `AccentColor` — so the asset
catalog will not fail a build with a missing-icon error, but it will ship a placeholder icon
until artwork lands.

On macOS the app needs the **Outgoing Connections (Client)** sandbox capability for RTMPS, and
**User Selected File** access for import. On iOS, background audio is already declared in the
generated Info.plist (`UIBackgroundModes = audio`).

---

## 2. Module map

| Group | What it owns |
| --- | --- |
| `Design/` | `Theme` tokens sampled from the mockup, and the reusable control-surface parts. |
| `Model/` | Pure value types: playlist, analysis, Visual DNA, score, output, health, session. |
| `Persistence/` | `SessionStore` — atomic JSON document, recovery journal, preset export/import. |
| `Audio/` | `AudioTransport` (AVAudioEngine graph + program clock), `FeatureExtractor` (vDSP), `DemoProgram` (synthesised nine-track programme). |
| `Analysis/` | Offline `TrackAnalyzer`, `ProgramAnalyzer`, and the job-running `AnalysisService`. |
| `Direction/` | `ArtDirector` (analysis → Visual DNA) and `ScoreCompiler` (DNA + analysis → `VisualScore`). |
| `Engine/` | Glyph vocabulary, palettes, grid, three scene families, titles, effects, transitions, safety envelope, `VisualEngine`. |
| `Render/` | `GlyphRasterizer` (CoreText batching), `ProgramRenderer` (the authoritative frame), `OffscreenFrameRenderer` (CVPixelBuffer). |
| `Broadcast/` | `VideoEncoder`, `AudioEncoder`, `FLV`, `AMF0`, `RTMPPublisher`, `SimulatedPublisher`, `LocalRecorder`, `KeychainStore`, `PreflightService`, `BroadcastCoordinator`. |
| `App/`, `UI/` | `StudioViewModel` and the studio surface. |

Dependencies point one way: UI → view model → (transport, renderer, coordinator) → engine and
encoders → models. Nothing in `Engine/` imports SwiftUI; nothing in `Model/` imports anything
but Foundation.

---

## 3. Decisions worth knowing

### One authoritative program image
`ProgramRenderer` produces at most one frame per video-frame interval and caches it. The SwiftUI
preview and the encoder both read that cache; neither advances the clock. This is what keeps the
preview and the stream from diverging, and it is why the preview costs nearly nothing while
sending.

### Program time comes from audio
The transport accumulates tap frame counts as the program clock. When nothing is playing, the
renderer advances a bounded fallback clock so the studio is never a dead rectangle. Visuals
follow audio; audio never waits for visuals.

### Concurrency: no actor isolation on the observable objects
`StudioViewModel`, `BroadcastCoordinator` and `AnalysisService` are plain `ObservableObject`s.
Audio taps, `DispatchQueue` work items and VideoToolbox callbacks are `@Sendable` contexts that
do not inherit main-actor isolation, so those types hop to the main queue explicitly and guard
shared mutable state with `NSLock`. `SWIFT_STRICT_CONCURRENCY` is set to `minimal` for the same
reason; tightening it is a deliberate follow-up, not an accident.

### Rendering is CoreGraphics, not Metal
`GlyphRasterizer` groups cells by (palette role × six intensity buckets), so a 240×68 grid costs
a few dozen `CTFontDrawGlyphs` calls instead of sixteen thousand. Phase 1 calls for a Metal glyph
atlas; the `FrameRenderer` protocol is the seam where that lands without touching the engine or
the encoder. Measure before replacing it — on Apple silicon the CoreText path may already hold
1080p30 comfortably.

### Two values, never merged
`BroadcastCoordinator.pipeline` says what this machine is doing. `visibility` says what the
destination claims. Nothing infers "live" from an open socket. Until a provider integration
exists, the only way to reach `creatorReportedLive` is the creator pressing the button in the
preflight sheet.

### Recording is independent of the link
`LocalRecorder` writes MP4 alongside the stream, and a failed publish never stops it. Reconnects
back off (2 s → 30 s, eight attempts) while the programme keeps playing.

---

## 4. What is *not* validated

1. **The RTMP client has never touched a live ingest.** Handshake, chunking, AMF0 command
   exchange and FLV packaging are written to the RTMP 1.0 specification and to YouTube's
   documented RTMPS ingest, but "written correctly" and "verified against `a.rtmps.youtube.com`"
   are different claims and only the first is true today. Validate with a throwaway key, watch
   for `NetStream.Publish.Start`, and check the ingest health page before trusting it.
   `SimulatedPublisher` (the **DRY RUN** chip in the studio) exercises the whole pipeline without
   a network so the rest of the app can be tested first.
2. **Nothing has been compiled.** Expect a first-build round of small fixes: deprecation warnings
   from `AVURLAsset.duration`/`tracks(withMediaType:)`, SwiftUI availability details, and any
   spelled-wrong SF Symbol names.
3. **Thermals and long runs.** The three-hour unattended session in the Phase 2 exit criteria has
   not been attempted. `EngineHealth` collects the numbers needed to judge it.
4. **Audio/video drift over hours.** Video PTS comes from a frame counter and audio PTS from an
   AAC packet counter. Both are derived from real clocks, but a multi-hour drift measurement has
   not been done. If drift appears, timestamp video from the same audio-derived program clock
   rather than from the frame index.

---

## 5. Deliberate deferrals

- **Metal renderer**, per above.
- **Nine of twelve scene families.** Three are implemented as specified (Folded City, Weaving
  Engine, Negative Space Theatre). The score compiler weights families by direction; adding a
  family is a new `SceneEpisode` plus a weight entry.
- **Provider integration (YouTube Data API).** Would upgrade `visibility` to
  `providerConfirmedLive`. The state exists; nothing sets it yet.
- **Score editing.** The timeline renders the compiled score and follows the playhead; dragging
  cues is Phase 4. Regenerating or recompiling is the current edit loop.
- **Rights sheet.** Rights are modelled, shown in preflight, and marked per row in the queue;
  the dedicated editor sheet is not built.
- **Tests.** None in this pass, by agreement. The first candidates are `AMF0` round-trips,
  `FLV.avcDecoderConfigurationRecord`, `SectionFinder` on synthetic audio, and `ScoreCompiler`
  determinism for a fixed seed.

---

## 6. Contracts a future change must not break

- `TrackAnalysis.extractorVersion` (3) and `VisualDNA.compilerVersion` (3) invalidate caches.
  Bump them when the analyser or the compiler changes meaning, never silently.
- Score determinism: scene seeds are `dna.seed &+ UInt64(sceneIndex &* 7919)`. Same playlist and
  same DNA must produce the same show.
- `photosensitivitySafe` filters effects at **compile** time and clamps luminance at **render**
  time. Both halves are required; removing either breaks the promise.
- Stream keys exist only in the keychain (`KeychainStore`), never in `StudioDocument`, exported
  presets, the recovery journal, or logs.
- The demo programme is generated by the app, so it is rights-cleared by construction. Imported
  music is never auto-declared on the creator's behalf.

---

## 7. First-run behaviour

With no saved document, the studio installs the nine-track demo programme, marks it cleared,
and shows the onboarding sheet with one obvious action: analyse it. After analysis the app
generates a Visual DNA, compiles a score, and the timeline fills in. Nothing has to be imported
and no key has to be pasted to see a finished channel — which is the point of the demo: the
first run should look like the product, not like an empty document.
