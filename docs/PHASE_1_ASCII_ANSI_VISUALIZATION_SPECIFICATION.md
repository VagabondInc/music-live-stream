# ASCII/ANSI Visualization System Specification

Phase 1 • Astra → GPT-5.6 Sol • Version 1.0 • 24 September 2026

**Decision:** Build a text-native performance engine that composes a visual score for a playlist, then performs that score against the actual music clock. Its defining features are persistent worlds, recognizable motifs, musical phrasing, deliberate transformations, and the visible behavior of characters as material.

This is a proposed design and implementation contract, not a report of a working engine. Numeric defaults, quality tiers, and acceptance thresholds below are starting requirements to validate in prototypes, not measured capabilities. Research-backed constraints are linked at their point of use. Creative proposals and parameter choices are original product recommendations.

**Scope:** Visualization analysis, direction, scenes, animation, glyph rendering, visual controls, and renderer boundary contracts. Authentication, source integrations, playlist editing UX, streaming protocols, full application architecture, and platform-wide navigation belong to Phase 2. No application implementation is included.

The handoff is deliberately specific about what Sol must preserve, what it may tune, and which feasibility questions must be answered before committing to a product promise.

**Reading paths:** Start with [creative vision](#1-creative-vision), [Visual DNA](#3-visual-dna-architecture), and [scene families](#8-scene-families) to assess the creative proposition. Use [rendering pipeline](#26-proposed-rendering-pipeline), [prototype experiments](#29-prototype-experiments-required), and the final [Sol handoff](#31-concrete-handoff-contract-for-gpt-56-sol) to plan development. [Engagement criteria](#30-criteria-for-engaging-rather-than-merely-reactive) define how to test the central product claim.

## 1. Creative vision

The broadcast should resemble a living edition of an art-directed publication: each track is a chapter, each musical section is a passage, and each character is a mark with a job. A window can become a bracket; a bracket can become a door; the door can become a letter in the next song's title. The audience should recognize the world without predicting its next image.

Three qualities define the experience:

- **Readable at a glance:** a silhouette, focal object, spatial relationship, or dramatic action survives a small preview and a distant television.
- **Rewarding with attention:** characters obey local rules; structures change for musical reasons; returning motifs carry visible history.
- **Comfortable in the background:** the engine leaves room for music, sustains quiet compositions, and earns its spectacular moments.

The fundamental creative unit is a **scene episode**: an entity or environment undergoing a legible change. Examples include an observatory opening its aperture, a loom weaving a bridge, a city exchanging its interior and exterior, or a small custodian collecting the remains of a broken title. A scene is not complete merely because something moves.

Every episode must have an establishment, an action, a consequence, and an exit possibility. These can be very subtle: an ambient passage may reveal that the slowly moving landscape is the inside of an enormous letter.

**Illustrative performance, not an analyzed real song:** Over a four-minute electronic track, the opening title appears as the destination of an empty station. A low-frequency pulse moves a single carriage through the station; percussion switches its points. As a repeated section returns, the station appears overhead as a map whose lines are the earlier rails. A sparse passage removes the map but preserves the carriage as a cursor. At the main release, the cursor opens an aperture onto a different scale of the same city. The outro leaves one illuminated window; that window becomes the reading lamp of the next track's archive.

This creates a causal sequence that an amplitude-driven texture cannot supply. The tradeoff is substantial authored content work: procedural variation multiplies well-designed scene grammars; it does not replace them.

## 2. Design principles

1. **Compose before decorating.** Establish subject, silhouette, space, and pacing before adding atmosphere or effects.
2. **React selectively.** A small event may move a mechanism; a section arrival may change the mechanism's purpose. Everything must not pulse together.
3. **Keep identities persistent.** Entities survive beats, phrases, and sometimes tracks. Their scars, routes, and relationships are part of the show.
4. **Give glyphs agency.** Character replacement, alignment, adjacency, spacing, and lexical assembly must change what the image means.
5. **Reserve spectacle.** High energy can produce precision, tension, scale, or stillness; it need not produce more motion.
6. **Treat uncertainty as a design input.** Unknown structure produces a capable free-running performance, not invented musical certainty.
7. **Prefer constrained variety.** A coherent small palette of behaviors beats an unrestricted effect lottery.
8. **Protect reading.** Metadata is real information and receives explicit space and time.
9. **Bound all work.** No scene can grow its state, history, GPU passes, or entity population indefinitely.
10. **Preserve the show under degradation.** Reduce secondary detail before destroying the focal action or disrupting audio timing.
11. **Separate creative desire from safety limits.** Neither a preset nor a high-energy track can bypass the output safety policy.
12. **Make automatic mode exemplary.** The first generated score must be presentable without repairing it through expert controls.

Useful precedents, and the product interpretation of them:

| Precedent | Verified interaction principle | Application here; friction to avoid |
|---|---|---|
| Resolume | Parameter envelopes and BPM animation give repeatable expressive control. | Ship musical envelopes already composed into scene roles; avoid requiring users to map dozens of sliders. [Resolume envelopes](https://www.resolume.com/support/en/envelopes) |
| TouchDesigner | Channels can be smoothed with separate rising/falling behavior and constrained velocity. | Expose meaningful responses such as “heavy” and “delicate,” backed by typed, smoothed signals; avoid mandatory patch construction. [Lag CHOP](https://derivative.ca/UserGuide/Lag_CHOP) |
| OBS | Studio Mode separates an editable preview from the visible program. | Offer a reversible visual audition when live; avoid accidental destructive preset changes. [OBS Studio Mode](https://github.com/obsproject/obs-studio/wiki/OBS-Studio-Overview#studio-mode) |
| projectM | Audio features drive a rich preset system. | Preserve instant discovery and favorites, then add a playlist score and persistent entities so changes have continuity. [projectM repository](https://github.com/projectM-visualizer/projectm) |
| Music-player convention | The current item and next item provide a simple mental model. | Pair the current track with one current visual chapter; expose the machinery progressively. This is a design analogy, not a competitive usability study. |

These are product hypotheses about reducing friction, not claims that these tools lack other capabilities.

## 3. Visual DNA architecture

Visual DNA is a versioned, constrained style program. It defines what belongs to this broadcast, rather than prescribing one animation.

Use four levels of specialization:

**Playlist DNA → program chapter → track interpretation → scene episode.**

Higher levels define allowable choices; lower levels choose within them. Audio response modulates the episode without rewriting its identity. A mixed playlist may have several chapters sharing a common typographic, motif, and transition system.

| DNA domain | Required contents | Example |
|---|---|---|
| Identity | Stable ID, name, seed, schema/compiler versions, source-analysis revision | “Night Transit,” seed 48271 |
| Glyph language | Vocabulary profile, functional subsets, font/atlas version, substitution graph | Sparse ASCII marks; brackets as thresholds |
| Composition | Focal hierarchy, negative-space range, symmetry tendencies, horizon zones | One offset subject; large dark upper field |
| World logic | Family weights, material rules, topology constraints, entity relationships | Infrastructure that gradually becomes organic |
| Motion grammar | Gesture vocabulary, response envelopes, speed and acceleration bounds | Delayed hinge, short recoil, slow settling |
| Camera grammar | Allowed shot types, travel limits, framing priorities | Locked wide shots; occasional lateral track |
| Color grammar | Semantic roles, approved palettes, interpolation paths, accent limits | Ink, paper, structure, signal, memory |
| Motifs | Two to four recurring forms with invariant signatures and mutations | A split arch with one missing cell |
| Transition language | Allowed bridges, carryable entities, direction tendencies | Object handoff; subtraction through space |
| Typography | Reading style, environmental style, title timing, safe regions | Quiet mono labels with generous tracking |
| Pacing | Scene dwell ranges, quiet-time objective, spectacle budget | Slow episodes; one major reveal per passage |
| Variation | Allowed axes, recurrence rules, history window, seeds | Geometry evolves; arch silhouette persists |
| Constraints | User locks, accessibility envelope, supported quality substitutions | No camera roll; no luminance inversion |

**Invariant versus variable:** A motif's silhouette and spacing rhythm can remain fixed while its material, size, location, and behavior change. A recurring arch might be a doorway, a loom shuttle path, a creature's ribs, or the shape left by erased text. Mere reuse of a logo does not satisfy motif continuity.

**DNA generation:** Analyze distributions and transitions, select an authored direction, solve for compatible families and motion/color/glyph rules, then instantiate motifs and a visual score. Do not average every track into an indistinct mood. Contrasting chapters should be allowed to disagree while sharing a recognizable alphabet.

**Stability:** Playlist edits preserve the chosen identity by default. Replan affected future passages; do not silently regenerate the whole DNA. “Generate another identity” is an explicit new variant. Locking a palette must survive later analysis updates.

Three concrete starting directions:

| Direction | Glyph/composition | World and motif | Motion/color | Transformational range |
|---|---|---|---|---|
| Night Transit | Strict ASCII structure; narrow columns; deep empty fields | Switchyard, apartment sections, observatory; split arch | Mechanical anticipation; charcoal, ivory, muted amber/cyan | Rails become diagrams; diagrams become city interiors |
| Living Index | ASCII letters plus selected box drawing; marginalia and terraces | Archive, woven landscapes, language organisms; a migrating pair of parentheses | Folding, growth, exchange; paper-like warm ground with ink and one botanical accent | Shelves unfold into terrain; annotations become migrating inhabitants |
| Tidal Instrument | Sparse punctuation plus optional Braille contour accents | Pressure chambers, tidal chambers, celestial instruments; a suspended bead | Long elastic releases; blue-black ground and restrained mineral accents | Waterlines become strings; strings become orbital routes |

These are starter art directions, not genre-exclusive skins. Each must support several families, compositions, and quiet/loud interpretations.

## 4. Audio-analysis inputs

The engine consumes permitted decoded audio or trusted timestamped analysis. It must not assume that playlist metadata, playback permission, raw audio, analysis permission, and rebroadcast permission are interchangeable. Phase 2 owns source verification. The visual engine reports its input capabilities honestly.

### 4.1 Measurement, inference, and interpretation

| Signal | Method and practical status | Use and limitation |
|---|---|---|
| Peak, RMS, band energy | Deterministic measurements of supplied samples | Local force, mass, tension; RMS is not perceived loudness |
| Spectrum, spectral centroid, rolloff, flatness | Windowed spectral measurements | Material texture and tonal/noisy balance; centroid is not emotional brightness |
| Spectral flux and onset candidates | Computed change measure plus adaptive detection | Local gestures; an onset is not necessarily a drum hit |
| Bass/mid/high activity | Weighted energy in specified bands | Different scene roles; never label bass energy “kick” without a classifier |
| Stereo balance, correlation, mid/side energy | Measurements of the mix | Local width and paired motion; not physical source positions |
| Tempo, beat phase, downbeat, meter | Estimates with confidence and alternatives | Phrase scheduling; half/double tempo ambiguity must remain representable |
| Chroma, harmonic change, tonal stability | Features plus inferred interpretation | Recurrence and material change; key/chord labels optional |
| Repeated sections and boundaries | Multi-feature segmentation and recurrence analysis | A/B/A′ structure; boundaries are uncertain and may exist at several scales |
| Intro/verse/chorus/bridge/drop labels | Semantic inference, rules or optional models | Advisory directing hints, never mandatory ground truth |
| Genre/subgenre, vocal presence, instruments | Metadata or optional classifiers | Soft priors; mixed music and out-of-domain material require “unknown” |
| Acoustic/electronic character | Inference from timbre/model/metadata | Material affinity; cannot be read directly from one spectral feature |
| Mood, valence, perceived intensity | Subjective estimates, optionally user supplied | Gentle art-direction bias; not objective measurement or artist intent |
| Rhythmic/harmonic complexity | Defined proxies with explicit windows | Distribution of activity and recurrence; do not claim a universal complexity score |

Repetition, homogeneity, and novelty provide useful structural evidence, but an inferred boundary does not by itself name a chorus. Use these methods to establish section identities first. [AudioLabs structure analysis](https://www.audiolabs-erlangen.de/resources/MIR/FMP/C4/C4.html)

### 4.2 Analysis lanes

**Fast lane:** Start evaluation with 1,024-sample onset windows and 2,048-sample spectral windows at a 48 kHz analysis rate; 256/512-sample hops respectively. Keep the native playback format outside the engine's analysis contract. Resample analysis only when needed. Use additional longer windows for low-frequency and harmonic information. These choices imply different time resolution and delay; no feature may pretend to be instantaneous.

**Phrase lane:** Aggregate roughly 0.5–2-second observations and beat-synchronous statistics where the beat is trustworthy. Track energy slopes, onset-density changes, harmonic changes, vocal activity probabilities, recurrence, and boundary candidates.

**Track lane:** For permitted local audio, pre-analyze the whole track. Produce tempo hypotheses, section graph, energy curve, repetition groups, and suggested anticipation cues. Downsample or sparsify self-similarity analysis so long tracks do not require an unbounded quadratic matrix. Stream the decode; do not retain the whole PCM asset in memory.

**Program lane:** Reduce track results to robust summaries and ordered transitions. Detailed audio windows remain in the track analysis, not in every playlist record.

vDSP provides the appropriate native FFT primitives; this specification recommends it for deterministic analysis rather than introducing ML for basic spectral measurements. [Apple vDSP FFT](https://developer.apple.com/documentation/accelerate/vdsp/fft)

### 4.3 Normalization and confidence

Keep raw units alongside normalized values. For a scalar feature, use robust track or rolling percentiles rather than a continuously chasing maximum. A starting transform is `clamp((x − P10) / max(P90 − P10, epsilon), 0, 1)`. Persist the percentile window and version. Quiet passages remain quiet because absolute level and relative intensity are separate channels. Silence gating prevents normalization from amplifying numerical noise into a show.

Do not normalize every song's peak into the same visual intensity. Track-relative dynamics determine articulation; program-relative energy influences pacing; user intensity limits the permitted output envelope.

Every inferred item carries a confidence score, method/version, coverage interval, and provenance. A score is a heuristic until calibrated; it must not be presented as a probability unless calibration supports that interpretation. Initial routing bands are high ≥0.8, provisional 0.5–0.8, low <0.5, to be tuned per estimator.

Beat tracking has response-time and confidence tradeoffs, particularly online. Confidence should control visual commitment rather than merely appear in a diagnostic panel. [AudioLabs real-time beat tracking research](https://audiolabs-erlangen.de/resources/MIR/2024-ARTBeaT)

### 4.4 Required degraded modes

- **Full analysis:** Precomputed track structure plus live alignment and mix features.
- **Live audio only:** Causal signals and provisional beat; no confident advance prediction of a drop. Anticipation is used only when sustained evidence supports it.
- **Partial analysis:** Use valid covered intervals; explicitly mark uncovered intervals and avoid extrapolating section labels indefinitely.
- **Metadata only:** Generate an autonomous, timed visual performance with disclosed “audio response unavailable” status in creator controls. Do not call it music-synchronized.
- **Silence:** After a configurable gate and hold, settle into a quiet tableau. Distinguish actual silence from missing samples; a missing feed generates an engine diagnostic.
- **Manual override:** User-supplied tempo/section markers have provenance and can override estimates without rewriting the original analysis.

### 4.5 Concrete structural-analysis proposal

Use the following baseline process before evaluating semantic ML:

1. Extract log-band spectral/timbral features, chroma where tonal evidence supports it, and an onset-strength sequence. Keep stereo features separate; mono analysis must not erase the original stereo evidence.
2. Create normalized feature sequences at coarse time resolution, with optional beat-synchronous versions where beat estimates are stable. Missing tonal evidence reduces chroma's contribution rather than producing a misleading key label.
3. Compare local windows across several scales—for example 2, 8, and 16 seconds—to propose boundaries from changes in timbre, harmony, and activity. Combine evidence with minimum separation and prominence criteria; a cymbal crash alone is insufficient for a macro boundary.
4. Construct a bounded recurrence representation for coarse segment features. Identify repeated or related intervals and label them A, B, A′, etc. These labels express similarity only. For long-form mixes, operate in overlapping chunks with summary links rather than allocating a full sample-level similarity matrix.
5. Keep alternative boundary times or uncertainty intervals when evidence is broad. Align a proposed boundary to a nearby credible beat only within its evidence interval. Never pull an acoustic transition several seconds away to satisfy an invented bar grid.
6. Suggest directing functions from local context: accumulation from sustained positive energy/activity slopes; release from a confirmed change following accumulation; breath from sustained reduction; return from recurrence. A louder section without a prior buildup can be a contrast rather than a “drop.”
7. Optionally attach semantic labels using an evaluated classifier or conservative rules. Display “repeated high-energy section” when that is what the evidence supports, instead of asserting “chorus.” Intro/outro depend on position and behavior; a track can start at full intensity and end abruptly.

Novelty-based segmentation provides a foundation for multi-scale boundary proposals; the directing functions and thresholds above are product-specific design choices that require validation. [AudioLabs novelty segmentation](https://www.audiolabs-erlangen.de/resources/MIR/FMP/C4/C4S4_NoveltySegmentation.html)

Track-level analysis may use future samples; online analysis must expose causal limits. Store both analysis completion coverage and estimator confidence. “Fully analyzed” means every permitted interval was processed, not that every inferred beat or label is correct.

## 5. Playlist-analysis model

Analyze the playlist as an ordered program, preserving its user-chosen order. Do not reorder tracks to simplify visual direction.

Each track summary contains duration, analysis availability, distributions of measured features, tempo hypotheses and stability, recurrence pattern, inferred semantic tags with confidence, and boundary summaries near its opening and ending. Summaries must identify whether they describe the whole track or only a sample.

Produce:

- Duration-weighted genre/tag distributions with an explicit unknown share; also retain track counts so one long piece does not erase minority styles.
- Energy and tempo trajectories over actual playback order, including uncertainty.
- Soft stylistic clusters based on normalized features and optional embeddings. Never force a track into a single genre.
- An adjacent-track compatibility graph and a separate recurrence graph for nonadjacent callbacks.
- Candidate program chapters: stretches of continuity or intentional contrast, with a small number of shared DNA anchors.
- A motif ledger that identifies where an earlier form can return with a new role.

Use a boundary distance composed from available dimensions: energy 0.30, timbre 0.25, rhythm 0.20, harmonic character 0.10, semantic tags 0.15 as an initial tuning model. Renormalize only across available dimensions and report coverage; low distance based solely on one weak tag is not strong compatibility. Compare both global track summaries and the actual outgoing/incoming boundary windows. Treat tempo ratios near 2:1 as ambiguous compatibility, not automatically distant.

**Continuous channel behavior:** Freeze the near-term score once committed. Appending tracks extends planning; deleting or skipping invalidates affected future cues. On shuffle, recompute adjacent bridges while retaining the playlist DNA. A playlist loop advances a program-cycle seed and develops existing motifs instead of resetting to its opening frames. Keep bounded history across cycles.

**Mixed-source failure:** If six tracks are analyzable and four are not, the identity must disclose its 60% track coverage and duration coverage. Unknown tracks inherit a conservative family mix and receive autonomous scenes until actual features become available.

Why this model: it supports both musical continuity and deliberate contrast without pretending that one scalar “mood” can describe a multi-hour channel. The tradeoff is a more explicit score representation and invalidation logic.

## 6. Temporal response model

The director schedules intention at four scales; the renderer executes it against a common rational media timeline.

| Scale | Typical horizon, not a hard music assumption | What changes | What should usually remain stable |
|---|---|---|---|
| Micro | 20 ms–2 s | Impact, local deformation, glyph articulation, small traversal | World, title layout, camera shot |
| Meso | 2–32 s or one/few phrases | Choreography, motif action, framing, local topology | Family and visual identity |
| Macro | Track sections and whole tracks | Episodes, scale, subject relationships, structural reveals | Selected motifs and DNA invariants |
| Program | Several tracks to hours | Chapters, motif history, family balance, palette evolution | Broadcast's recognizable signature |

Use five directing states: **establish → develop → withhold → release → settle**. They are visual functions, not synonyms for intro/verse/chorus. A chorus may withhold through an unexpectedly motionless monumental image; a breakdown may develop fine detail.

Represent an episode with a bounded state machine and a score of cues, envelopes, prerequisites, and exits. Repeated musical sections return to related compositions with altered scale or consequence. Avoid changing family at every section.

Initial automatic pacing rules:

- Typical primary episode dwell: 24–90 seconds; 45–180 seconds in contemplative direction. A short track may contain only one.
- Shot or tableau changes: normally 8–32 seconds; allow longer holds. Beat boundaries do not automatically mean cuts.
- Maintain at most one dominant gesture, one secondary gesture, and a subordinate atmosphere at once.
- A major reveal consumes a spectacle token. Refill no faster than 45 seconds in the default direction; musical suitability is still required.
- Aim for 20–35% of a typical program in low-activity compositions; this is a style-tunable pacing target, not a quota that interrupts a musical climax.
- After a release, reduce activity debt before adding another peak. Do not respond to every louder event with another escalation.

**Confidence changes:** Lose beat confidence gradually: decay phase-dependent motion over two seconds, retain local onset response, and return to measured seconds. Reacquire phase over several credible beats instead of snapping the world. Do not infer a four-beat bar from tempo alone. Compound, odd, changing, and absent meters must remain possible.

**Latency:** Each feature declares its analysis-window center, lookahead, processing latency, and valid time. Precomputed cues can anticipate a boundary; causal cues cannot. For live input, use an explicitly negotiated bounded visual/audio alignment delay only if the later playback system supports it. Otherwise accept measured visual lag rather than faking anticipation.

**Discontinuities:** Seek, skip, pause, source replacement, and loop boundaries are typed transport events. Reset stale onsets and beat estimators appropriately. Seek reconstructs scene state from a checkpoint/score; it does not simulate every missed frame on the audio thread. Pause holds the performance clock. Any optional ambient preview animation uses a separate, clearly non-program clock.

## 7. Scene architecture

Use authored procedural **scene families**, instantiated as **episodes**, assembled from reusable entities, materials, and choreographies. A family defines meaningful actions, not just geometry.

Required family manifest:

| Field | Contract |
|---|---|
| Identity/version | Stable family ID and content version; migrations or explicit incompatibility |
| Dramatic vocabulary | Establishing actions, transformations, consequences, resolution/exit actions |
| Entities | Stable IDs, roles, bounded populations, carryable state and relationships |
| Capabilities | Needed feature channels, supported glyph profiles, permitted quality tiers |
| Parameters | Typed ranges, units, defaults, live-edit behavior, dependencies |
| Composition | Focal constraints, text anchors, protected zones, negative-space rules |
| Music ports | Semantic inputs such as pressure, articulation, recurrence, release |
| Transition ports | Accepted/output motif carriers, entry/exit masks, compatible bridges |
| Resource bounds | Entity cap, cell work, geometry work, history length, texture/pass budget |
| Safety declarations | Camera range, high-contrast pattern risks, permitted substitutions |
| Determinism | Seed streams, state checkpoint schema, replay compatibility |
| Fallback | Simplified tableau and readable metadata anchor |

Episode lifecycle: **planned → prepared → active → exiting → retired**. Preparation includes resource validation, title layout, safety eligibility, and first-frame readiness. Only prepared content can enter the program. Retired resources leave through bounded pools, not unbounded caching.

Each entity has an authored role, geometry/topology, glyph material, motion state, salience, and optional memory. A “window” can own its contour, foreground/background, opening action, and carryable signature. This allows interaction between layers without every renderer inventing its own ad hoc rules.

Inter-family continuity uses a small vocabulary of portable carriers: point, path, frame, ribbon, fragment collection, textual token, and silhouette. A transfer adapter maps the carrier's identity and visual invariants into the next family. Arbitrary geometry morphing between all pairs is not required or credible.

## 8. Scene families

The initial creative library should contain at least eight genuinely distinct families before claiming multi-hour variety. Prototype three deeply before expanding. The following twelve provide a concrete development vocabulary.

| Family | Dramatic action and text-native mechanism | Musical behavior | Transformation/callback |
|---|---|---|---|
| **The Folded City** | Building sections unfold as nested punctuation; rooms change adjacency while inhabitants remain anchored. | Low-band pressure operates structures; phrase boundaries open new sightlines. | A room becomes an island or letter counter; a lit window survives the transition. |
| **The Weaving Engine** | Characters are warp and weft; rows carry material, knots retain events, gaps form bridges. | Onsets place stitches; repetition repeats a pattern with altered tension; a release changes the weave's scale. | Fabric becomes terrain, railway, or creature skin. |
| **The Archive of Weather** | Shelves of glyph objects accumulate, sort, erode, and drift under local weather. | Sustained timbre changes erosion; percussion releases individual fragments; quiet reveals annotations. | A recurring object gains sediment from earlier tracks. |
| **Negative-Space Theatre** | Solid fields of characters reveal moving rooms and figures through absence. | Music changes the boundary of what is missing; restraint carries tension. | A void closes into a title or opens into the next world. |
| **The Tidal Instrument** | Chambers, reservoirs, valves, and suspended strings exchange bounded quantities of glyph material. | Bass changes pressure; mids alter routing; phrase arrivals open sluices. | A waterline becomes a string, then an orbital path. |
| **Migratory Punctuation** | Small agents made of brackets and marks cooperate, build shelters, exchange loads, and leave paths. | Rhythmic density changes coordinated activity; rests allow inspections and regrouping. | One recognizable agent travels between otherwise unrelated scenes. |
| **The Impossible Workshop** | Tools manufacture objects that recursively contain the workshop, using grid rewrites and scale reveals. | Repeated riffs repeat operations; an A′ section changes the manufactured object. | Camera framing reveals yesterday's machine inside today's artifact. |
| **The Cartographic Sea** | Contours become coasts, routes, tides, and folded maps; labels behave as landmarks. | Harmonic novelty changes topology slowly; stereo width affects local channel separation. | A route becomes a city street, stitch, or sentence baseline. |
| **The Language Garden** | Letters grow as stems, punctuation becomes joints, and invented word-shapes bloom and decay. | Vocal-presence estimates reserve breathing room; sustained texture drives branching. | Branches gather into readable metadata before dispersing. No fabricated lyrics. |
| **The Observatory of Small Events** | Mechanical apertures frame distant glyph phenomena; tiny changes have monumental scale. | Quiet details receive local attention; major boundaries reveal what the instrument observes. | Aperture/frame carrier links to doors, windows, and typographic counters. |
| **The Palimpsest Stage** | Scenes are typed, corrected, overprinted, partly erased, and reinterpreted; old marks remain as controlled memory. | Recurrence restores earlier marks; new sections change their grammatical role. | An old title's structural outline becomes scenery, while its readable content leaves. |
| **The Pocket Cinema** | Small staged micro-stories: a lamp looking for its shadow, stairs assembling under a traveler, a caretaker repairing a horizon. | Phrase cadence sets actions; impacts alter props; the scene continues causally between beats. | Character/prop histories recur across tracks without requiring a literal plot. |

Do not code all twelve as different generators over the same particle/height-field substrate. Each needs a different state model and dramatic vocabulary. Share mechanics only where behavior is truly shared.

Three prototype episodes should be fully authored:

**Folded City / “The Station Opens”:** Establish a single concourse and an incomplete arch. Develop through doors opening onto contradictory rooms. Withhold by stopping the carriage while its route continues to assemble. Release by unfolding the concourse into an overhead map. Settle around one persistent window. Low quality removes distant rooms but preserves the reveal. Reduced motion uses sequential architectural states and soft transitions instead of camera travel.

**Weaving Engine / “A Bridge from the Rhythm”:** Establish two separated margins. Onsets place short local stitches; recurring phrases repeat a motif without duplicating every stitch. A meso cue links the margins; the next recurrence reveals an inhabited bridge. A missed beat does not tear the bridge apart. A quiet section leaves suspended threads and legible negative space.

**Negative-Space Theatre / “The Visitor”:** Establish a dense wall and one unprinted doorway. A small figure exists as an absence; its passage leaves temporary gaps that slowly close. The section change reveals that the wall is the inside of a giant object. The exit joins empty space to the next scene. Strict ASCII still produces the complete composition; blocks merely change its surface character.

The recurring figure must be visually authored and intentionally limited. An LLM inventing a new plot every track would weaken consistency and introduce unnecessary runtime dependency.

## 9. Layer and compositing architecture

Use a semantic scene graph plus a staged compositor. The conceptual layers are roles, not necessarily one full-resolution render target each.

| Role | Responsibility | Interaction rules |
|---|---|---|
| Background world | Horizon, far structure, slowly changing environment | Low salience; relinquishes detail behind text |
| Structural elements | Architecture, terrain, machinery, main topology | Own depth and attachment anchors |
| Reactive entities | Focal characters/objects performing actions | Read semantic music ports; do not move the entire world by default |
| Atmosphere | Sparse dust, weather, echoes, residue | Bounded density; cannot obscure subject or title |
| Environmental typography | Signs, labels, diegetic text | May inhabit world depth; reading mode locks its legibility |
| Transient effects | Local event punctuation and transformations | Masked by ownership; use a global intensity budget |
| Camera | Framing and projection | Acts on world space, not on protected reading overlays |
| Broadcast graphics | Now-playing, optional branding | Reserved screen-space readability and timing |

Entities exchange events through typed scene ports, for example `doorOpened`, `carrierReleased`, or `routeCompleted`. Atmosphere may respond to a structural event; it should not infer causality from arbitrary framebuffer colors.

Use depth, coverage, object ID, material role, salience, and protected-text masks. Resolve ownership before choosing the final glyph. A foreground cell must not accidentally combine the contour of one object with the density ramp of another. Transparency is deliberate glyph/material coverage, not an uncontrolled stack of alpha-blended letters.

Recommended order: world evaluation → ownership/depth → field and topology effects → glyph assignment → glyph-space effects → raster composition → limited finishing → protected reading text → final output safety/color validation. Environmental text may appear earlier, but its screen projection contributes a protection mask. Nothing after the final validation may reintroduce an unsafe effect.

Use premultiplied alpha and explicit color spaces where blending is needed. Debug views should expose ownership, salience, typography exclusion, and safety interventions. Default users see the result, not these engineering overlays.

## 10. ASCII/ANSI rendering methodology

**Primary representation:** A character field with semantic ownership, driven by scene geometry and topology. A scene may use 2D constructions, 2.5D layers, or 3D geometry, but its expressive rules operate on glyphs and their spatial relationships.

Two complementary construction paths:

1. **Direct glyph construction:** Assemblies, line networks, typography, rewrite rules, cellular operations, and character agents directly specify cells or glyph instances. This is the preferred path for architecture, weaving, theatre, and narrative objects.
2. **Material-aware sampling:** A geometry pass supplies silhouette, depth, normal/orientation, coverage, and material identity. Glyph selection renders those properties using an authored vocabulary. Use for complex surfaces and spatial scenes, with topology and character behavior still supplying the main action.

A generic shaded image followed by brightness-to-character conversion is only an optional material/effect. It cannot be the scene architecture.

Each logical cell records glyph/atlas ID, foreground/background roles, coverage, depth class, entity ID, orientation class, protection flags, and stable variation key. Final GPU packing is an implementation choice; avoid storing redundant full-precision data without profiling.

Glyph selection scores eligible candidates against coverage, edge orientation, connectivity, material role, and temporal stability. For lines and junctions, connectivity wins over brightness. For silhouettes, contour integrity wins over interior detail. For readable text, the actual shaped glyph sequence wins over both.

Use hysteresis to prevent glyph chatter: do not replace a cell for a tiny score advantage. Example starting rule: require a 10–15% improvement or a deliberate semantic event; normally hold interior glyphs for 80–150 ms. Moving silhouettes and text are exempt when holding would create trails or corrupt a shape. Thresholds must be tested at each grid scale.

World positions can be continuous while cell assignments are discrete. Stable spatial sampling and quantized updates prevent slow movement from turning into random sparkle. Dithering should use stable spatial patterns anchored to objects or the grid; uncorrelated per-frame noise is prohibited in default materials.

Account for glyph aspect ratio in projection. With cells twice as tall as they are wide, a 16:9 canvas uses roughly 32:9 columns to rows. At 1080p, 160×45 cells yields 12×24-pixel cells; 240×68 is a denser approximation. Never assume square cells.

“ANSI” denotes an artistic vocabulary of foreground/background colors, blocks, box drawing, and terminal behavior. The broadcast is rendered video, not a terminal emulator executing escape sequences. Never execute track titles or imported preset strings as terminal controls. True `.ans` or terminal export, if later desired, is a separate compatibility feature with reduced capabilities.

## 11. Glyph strategy

Provide three deliberate art vocabularies:

| Profile | Repertoire | Best use | Limitations |
|---|---|---|---|
| Strict ASCII | Printable U+0020–U+007E, with control characters excluded | Strong textual identity, structural scenes, restrained typography | Curves and solid silhouettes require compositional adaptation |
| Terminal | Strict ASCII plus a curated fixed-width box-drawing, block, and shade repertoire | Architecture, solid/empty contrasts, mechanical surfaces | Requires verified font metrics; “ANSI” does not imply a universal encoding |
| Expanded | Terminal vocabulary plus selected Braille and a small audited Unicode symbol set | Fine contours, woven surfaces, special material accents | Can resemble low-resolution graphics if overused; broad Unicode is not automatically grid-safe |

The vocabulary setting applies to **art glyphs**. Song titles and artist names retain their real scripts through a separate shaped text path. Strict ASCII art must not silently transliterate or corrupt someone's name. An optional user-approved display alias is separate from original metadata.

Functional glyph sets should be explicit: contour, junction, mass, grain, flow, agent anatomy, language, and blank. Space is a first-class glyph with compositional meaning.

Build an atlas profile with measured coverage, centroid, stroke direction, connectivity, advance, baseline, and valid cell occupancy. A hard-coded universal density ramp is inadequate because fonts differ. Favor one bundled, appropriately licensed art font per direction at first; bundle/versioning improves replay stability. Metadata fallback fonts must be recorded where exact output repeatability matters.

Character morphing uses a substitution graph. A hinge may evolve `.` → `:` → `|` → `[` because these shapes share an authored action; it must not pass through arbitrary alphanumeric noise. Density substitutions stay within material roles. Semantic letters are protected from such mutation while they are being read.

Braille patterns supply up to a 2×4 arrangement of dots per character, useful for contours, but decorative Braille is not an accessibility representation. Prevent decorative character streams from being announced by VoiceOver. The artwork gets a concise scene description instead.

Do not trust Unicode code-point count as display width. Shape readable text with native text services, including bidirectional layout and combining marks; restrict art glyphs to tested atlas entries. Unicode's width property itself requires contextual tailoring and is not a complete terminal layout solution. [Unicode East Asian Width](https://www.unicode.org/reports/tr11/)

Unsupported glyphs fail validation before a preset goes live. Show the creator the substituted art profile. Missing metadata glyphs use a proper font fallback, not random boxes. Do not silently replace a required motif character with an unrelated glyph.

## 12. Color system

Use semantic palette roles rather than free random RGB values:

- **Ground:** establishes the visual field.
- **Structure:** separates the world from the ground.
- **Subject:** distinguishes the focal entity.
- **Signal:** carries limited event emphasis.
- **Memory:** identifies remnants or callbacks.
- **Reading:** maintains text legibility over a reserved reading surface.

Default to two to four active non-ground roles in a shot. A richer Terminal palette may exist, but all colors must retain assigned responsibilities. Monochrome can still express depth through density, stroke orientation, occlusion, and negative space.

Generate palettes from approved endpoints and paths in a perceptual color space such as OKLCH, then gamut-map to the output profile. Compositing uses a defined linear-light working space. Palette interpolation must constrain luminance as well as hue; a “smooth hue change” can still create an abrupt brightness change.

Program evolution moves through related palette states over phrases or chapters, typically 15–60 seconds for a substantial drift. Track changes may introduce a new accent while preserving the ground and reading roles. Avoid automatic genre stereotypes such as “minor key equals blue.”

Start with SDR, explicitly tagged Rec.709 broadcast output. Treat display preview conversion and encoded video conversion as separate color-managed consumers. HDR should be deferred until an independently validated rendering, safety, and output contract exists. Wide-gamut display capability alone is not a reason to produce wide-gamut stream frames.

Color-blind-safe variants require redundant shape, density, or position cues. Test all meaningful distinctions in grayscale and with common color-vision simulations; no palette is universally safe merely because it avoids red/green.

Thin saturated glyphs can suffer after chroma subsampling. Protect reading text with luminance contrast and sufficient stroke weight. Prototype compressed playback, not just pristine Metal previews, before accepting a palette.

## 13. Motion system

Motion is a vocabulary of actions with physical or typographic intent:

| Gesture | Character | Musical use |
|---|---|---|
| Hinge/open | Anticipation, one purposeful movement, settle | Phrase arrival, harmonic opening |
| Load/release | Accumulation with visible resistance | Sustained buildup followed by a confirmed boundary |
| Stitch/step | Small discrete event leaving persistent state | Selected onsets and repeated rhythm |
| Fold/unfold | Changes adjacency or reveals an interior | Structural transformation |
| Exchange | Two entities transfer material or responsibility | Call-and-response or alternating phrases |
| Grow/erode | Slow topology change | Long timbral change, ambient development |
| Align/scatter | Agreement or loss of order within a bounded field | Recurrence, rupture, recovery |
| Trace/erase | A path appears and becomes meaningful | Melodic activity proxy, title formation |
| Inspect/wait | Small orienting action followed by stillness | Rests, low-energy detail, anticipation |

Each gesture has attack, optional hold, release, travel range, velocity/acceleration limits, spatial support, event priority, and interruptibility. “Bass response” cannot directly set an arbitrary displacement without these constraints.

Separate **force** from **state**. An onset may add a bounded impulse to a spring or commit one stitch. Sustained bass can change pressure. Repetition changes a stored pattern. Do not integrate an unbounded energy signal into position or entity count.

Use deterministic curves and fixed-step bounded simulations. Prefer damped springs, explicit envelope curves, path traversal, and discrete topology operations to unconstrained chaotic physics. A high frame rate improves sampling of the same motion; it must not increase the number of events.

Initial local response envelope: attack 20–50 ms, release 180–600 ms, with a 100–250 ms refractory period appropriate to the gesture. Tiny percussion can articulate frequently at low contrast; full-screen movements cannot inherit that rate. Slow material responses use 1–8-second smoothing. These are authoring defaults, not universal mappings.

Separate user controls for event strength, amount of moving content, camera travel, and structural change rate. One “intensity” macro may coordinate them, but advanced users must not be forced to make all four louder together.

## 14. Camera system

The camera should behave like an editor framing an event. Continuous wandering undermines object memory and makes all worlds feel similar.

Supported shot grammar:

- Locked tableau with a strong composition.
- Slow lateral track revealing a relationship.
- Controlled push/pull revealing scale.
- Overhead diagram or sectional view.
- Match cut retaining a silhouette or screen-space anchor.
- Occlusion reveal using an authored foreground structure.
- Rare perspective fold or impossible-space passage.

Use shot templates with focal entity, start/end framing, duration, easing, permitted travel, text exclusion zones, and exit conditions. A camera move must have a reveal to justify it. No endless orbit as a default scene.

Automatic camera roll and beat-synchronized camera shake are off. Bass should normally act inside the frame. Strong roll/shake need not ship in the initial library; advanced control is not an obligation to expose every risky motion.

Keep glyphs screen-aligned by default, using depth/orientation to choose forms; this preserves the medium's legibility. World-aligned glyph surfaces are permitted for walls, fabric, and signage, but require minimum projected size and a screen-space reading fallback. Avoid shrinking important letters into shimmering subpixel marks.

Reduced motion converts a traveling reveal into two or more carefully composed static states with restrained dissolves. It should preserve the idea of revealing an interior without simulating motion through a tunnel.

## 15. Effect library

Effects are authored punctuation. Each effect declares trigger eligibility, space of operation, duration, affected area, salience cost, cooldown, conflicts, text protection, and safe substitution. A global arbiter decides whether it may run.

Initial library and defaults:

| Effect | Appropriate event and implementation | Constraint / conservative substitute |
|---|---|---|
| Local glyph burst | Strong isolated onset separates a bounded fragment group | ≤1 focal burst/4 s; fragments settle or retire; substitute a small outward contour |
| Cascading rewrite | Phrase develops through ordered column/row substitutions | Spatial wave, not random flicker; protect reading text |
| Fragment/reconstruct | Confirmed rupture followed by a new section | Preserve object IDs and reconstruction target; ≥45 s cooldown |
| Character displacement | Local pressure bends cells or shifts a contour | Clamp distance and acceleration; no unrestricted whole-screen jitter |
| Scan deformation | A deliberate scan crosses one object | Slow single pass; no moving high-contrast stripe comb |
| Controlled corruption | Short structural disruption with visible recovery | Rare, bounded region; never corrupt title or actual status UI |
| Glyph shockwave | A path-connected ring changes orientation or spacing | Local footprint and restrained luminance; no repeated flash ring |
| Trail/echo | A meaningful moving entity leaves decaying character history | Fixed history length and opacity; exclude readable text |
| Temporal smear | A selected gesture stretches across recent states | Bounded memory; safe mode uses a static residue |
| Feedback memory | World retains a faint previous topology | Capped gain/decay; deterministic state; no runaway amplification |
| Character rain | Material falls through a local environmental system | Limited region and purpose; never a default full-screen replacement |
| Glyph wipe | Transition front reconstructs cell ownership | Stable ordering; safe mode uses slow low-contrast dissolve |
| Density migration | Mass transfers between regions while preserving silhouette | Avoid large synchronized luminance oscillation |
| Palette inversion | Rare, authored change of ground/figure roles | Slow controlled remapping only; rapid inversion excluded; disabled in safe mode |
| Simulated signal loss | A world briefly loses organization then recovers | Clearly fictional inside the artwork; no fake system error; ≥3 min cooldown |
| ASCII sorting | Characters reorder along a field or semantic line | Segment-limited, scene-relative; no repeated whole-frame slicing |
| Perspective fracture | Parts separate into alternative depth layers | Use only at strong macro cue; reduced motion uses static arrangements |
| Cursor trace | A marker assembles a line, mechanism, or title | No incessant blinking; metadata reaches a stable reading state quickly |

Default limits: one focal transient at once; one secondary low-salience effect only if its footprint is disjoint. Initial focal-transient token bucket: capacity 2, refill one token per 8 seconds. A major effect consumes both and obeys its own longer cooldown. Ordinary small mechanical articulation is not a focal transient, but still consumes motion/safety budget.

Effects share conflict tags: displacement, temporal history, luminance change, camera dominance, title entry, and topology replacement. Two individually attractive effects may be rejected together. Priority is safety → readability → deliberate creator cue → structural cue → beat cue → decoration. Creator cues cannot override the first two.

A rejected effect should use a meaningful substitute or no effect; it must not wait in a queue and fire after its musical moment has passed. Analytics record why it was suppressed without cluttering the live preview.

## 16. Music-to-visual mapping system

Map features through **semantic control channels**, then through family-specific behaviors:

**Measured/inferred input → normalization → confidence gate → envelope → semantic channel → scene action → global arbitration → safety envelope.**

Core semantic channels:

| Channel | Evidence | Typical result | Explicit prohibition |
|---|---|---|---|
| Weight | Low-band energy and envelope | Pressure, mass, settling | Whole-screen brightness on every kick |
| Articulation | Onsets and rhythmic density | Stitch, valve, joint, small agent action | One new scene per transient |
| Texture | Flatness, centroid, spectral shape | Material/glyph subgroup | “High centroid means happy” |
| Space | Stereo measurements and phrase context | Local width, paired relationships | Rotating the whole camera with channel imbalance |
| Tension | Sustained energy slope plus rhythmic/harmonic change | Compression, alignment, withheld action | Predicting a drop from a single loud sample |
| Release | Confirmed section boundary and contrast/recurrence | New relationship, scale reveal, simplification | Automatic flash/explosion at every chorus |
| Breath | Falling activity, rest, silence confidence | Hold, opening space, reduced movement | Treating missing audio as intentional silence |
| Memory | Section/track recurrence | Return of a motif in altered form | Exact replay of the same animation |
| Presence | Optional vocal-presence confidence | Fewer competing events, a more direct composition | Generating fake lyrics or pretending to identify a singer |

Mapping records require source ID, unit/range, normalization revision, confidence rule, envelope, target semantic port, output bounds, priority, refractory period, and missing-input behavior. Event mappings are distinct from continuous mappings; a scalar spike cannot accidentally trigger the same event every frame.

Two examples:

**Low-band onset → city gate:** Band-limited flux proposes an event; the detector suppresses duplicates and emits an ID. If confidence and the gate's cooldown permit, the gate receives a 35 ms attack/320 ms release impulse up to its 8-degree authored travel. A 2-second weight envelope sets its resting resistance. No camera motion or global light pulse is implied.

**Return of section A → weaving callback:** The recurrence graph proposes `return(A, confidence)`. On a reliable phrase boundary, the loom restores the earlier stitch rhythm but expands its span and leaves one deliberately missing knot. An A′ label changes the transformation, not just the color. If recurrence is uncertain, preserve the material without asserting the full callback.

Mappings are many-to-few at any moment: select the two or three inputs that explain the scene's current action. A diagnostic “Why did this happen?” view exposes the event and rule; automatic mode presents only a short sentence such as “The returning refrain reopened the station.” Use neutral wording when the semantic label is uncertain.

## 17. Song-transition engine

A transition is a small authored performance between two worlds. It must be planned from the actual outgoing/incoming music and supported by the playback boundary contract, not an assumed crossfade.

Inputs: outgoing/incoming track instance IDs, boundary feature summaries, confirmed transition time, optional actual overlap/gain envelopes, next scene readiness, motif carrier, history, metadata windows, and accessibility profile.

| Musical relationship | Preferred visual strategy | Timing behavior |
|---|---|---|
| Similar pulse/timbre and real overlap | Match action or extend a shared structure | Carry an action across the actual overlap; phase-lock only if phase compatibility is reliable |
| Related identity, different energy | Retain a carrier while changing scale or space | Settle or expand over roughly 2–6 s |
| Strong contrast, no overlap | Resolve through negative space, then establish a new world | Use a prepared short bridge around the boundary without delaying audio |
| Abrupt intentional cut | Matched silhouette cut or safe structural replacement | Honor the cut; don't invent a slow audio transition |
| Unknown next track | Neutral carryable tableau with flexible exits | Keep audio running; enter the prepared next family when available |
| Short interlude/ident | Transform the existing scene rather than fully replacing it | Preserve identity and avoid title/transition overload |

Transition vocabulary: portal/frame handoff, shared-path transformation, architectural fold, glyph-vocabulary migration, negative-space passage, contour match, title collapse, local reconstruction, long atmospheric dissolve, and rare simulated terminal reset.

These transitions have prerequisites. A frame handoff requires both scenes to accept a frame carrier. If incompatible, select a neutral bridge rather than forcing arbitrary mesh morphing. Title collapse requires a validated readable title layout and spare reading time.

A standard transition reserves at most two fully active scenes. A bridge reuses one of those slots or uses a lightweight glyph tableau. Do not accidentally require three expensive worlds at once. Prewarm the incoming resources before the boundary; if unavailable, keep the outgoing world in an authored exit hold.

Variation: do not repeat a transition family within the previous three boundaries when alternatives satisfy constraints. Reuse may still be correct for a deliberately recurring chapter marker. Track the transition's composition and direction as well as its family.

During overlapping audio, continuous mix features describe what is actually heard. Track-specific analysis guides identity; master events are arbitrated using actual gain envelopes, so two beat detectors do not produce double-strength responses. Do not linearly average BPM values. Metadata attribution follows the explicit current-track policy supplied by playback.

Unexpected skip cancels uncommitted cues, starts a short safe exit, and hands off to the new track's prepared or fallback scene. No waiting for analysis before audio can continue. A transition's animation must never change playback timing.

## 18. Metadata and title treatment

Default reading windows are the first 10 seconds and final 10 seconds of a known-duration track. Include at most 0.6 seconds of restrained entry and 0.4 seconds of exit inside each window, leaving about 9 seconds stable at the default. The actual title/artist should become readable together; do not spend most of the window typewriting a long title.

For duration `D`, use intervals `[0, min(10,D)]` and `[max(0,D−10), D]`, unioning overlaps. For tracks shorter than 20 seconds, this produces one continuous reading interval rather than two competing cards. Users can change duration, choose always-on/on-demand, and independently enable opening/closing windows. Seeking evaluates the interval at the new track position; stale scheduled cards cannot fire afterward.

If duration is unknown, show the opening window and on-demand metadata. Show a closing window only when a trustworthy end time or scheduled boundary provides sufficient notice. An unexpected skip cannot provide ten seconds of advance notice; close the outgoing title and prioritize the new one.

Information hierarchy: title → artist → optional album/year → optional progress → restrained channel branding. Never invent missing album/year data. Artwork is optional and accepted only with source-provided permission/capability; it must not be required for a coherent title treatment.

Provide three presentation modes:

- **Environmental:** a sign, page, machine label, or architectural opening aligns into a readable surface.
- **Transformed:** scene fragments become a title, then settle into an ordinary readable text layout.
- **Quiet caption:** a designed screen-space typographic composition with generous whitespace, integrated through palette and alignment.

Every scene supplies a reading anchor and a quiet-caption fallback. Environmental integration is allowed only while projected glyph size, orientation, contrast, and occlusion pass. A title must not become a moving perspective puzzle. A discreet stable reading surface is appropriate when the world cannot otherwise protect text.

Starting layout targets for a 16:9 1080p output: 5% inset from edges; title cap height around 40–60 pixels and artist around 28–36 pixels, with scalable type roles rather than fixed raster assets. Confirm readability at 720p and at a 640×360 playback window; increase reading size or simplify secondary fields when necessary. Broadcast typography sizing is independent of the creator's Dynamic Type setting.

Long titles wrap into a bounded multiline layout; omit optional fields before shrinking required text. Avoid marquees. If content exceeds the tested layout limit, offer an explicit display alias and retain full metadata in controls; a safe fallback uses labeled ellipsis rather than inventing text. Native shaping supports right-to-left scripts, combining characters, and mixed-script names.

Reserve text space before scene composition. While reading, reduce competing movement and protect text from corruption, feedback, trails, and glyph substitutions. Titles cannot repeat in feedback history after their window ends. If incoming and outgoing reading windows overlap, use a deliberate two-title layout when space permits or the playback attribution policy; never stack arbitrary cards.

Use at least 4.5:1 nominal text/background contrast for informational broadcast text, aiming for 7:1 in the high-contrast variant. WCAG permits 3:1 for qualifying large text, but the product's 4.5:1 floor avoids relying on unknown playback size. Validate stroke weight and compressed readability as well as nominal colors. [W3C contrast minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)

## 19. Variation and anti-repetition system

“Effectively unbounded” means a large, intentional space of evolving performances. It does not mean a mathematical guarantee of never repeating finite state, or that random seeds automatically produce new art.

Variation operates across independent meaningful axes:

| Axis | Example | Identity protection |
|---|---|---|
| Topology | Different room adjacency, route network, weave structure | Preserve characteristic motifs and construction rules |
| Cast | One traveler, paired agents, a caretaker and object | Retain clear roles and bounded populations |
| Choreography | Build, inspect, exchange, dismantle, reveal | Use the family's authored action vocabulary |
| Composition | Asymmetric wide shot, section view, close tableau | Keep focal hierarchy and whitespace standards |
| Material | Sparse marks, contour lines, woven letters | Stay inside DNA vocabulary |
| Camera | Locked, lateral reveal, scale reveal | Respect movement and reading constraints |
| Palette | Related ground/accent states | Keep semantic roles and contrast |
| History | Missing knot, repaired arch, accumulated route | Carry only bounded, legible memory |
| Musical interpretation | Pressure versus precision at high energy | Preserve correspondence to real events |

Use hierarchical seeds derived from playlist identity, program cycle, track instance, episode ID, and named subsystem. Adding dust must not reseed the camera. Repeated copies of the same track have distinct instance IDs; “repeat exactly” is an explicit replay option.

Maintain three histories:

1. **Recent constraints:** family, shot, gesture, palette, and transition recency across approximately the last 12 episodes and 6 tracks.
2. **Program distribution:** exponentially decayed usage and salience over a longer horizon, initially two hours.
3. **Motif ledger:** a small bounded set of identities, their last appearances, transformations, and unresolved visual opportunities.

Candidate scoring combines musical fit, DNA fit, compositional validity, novelty, and callback value. Reject safety/resource violations before scoring. Repetition penalties should consider a tuple such as family + action + composition + camera + motif state, not just family name. A familiar family may be welcome when its dramatic role changes.

Add output-level fingerprints: a low-resolution luminance/occupancy map, edge distribution, dominant layout, and coarse motion signature. Compare multi-second windows to recent output; allow intentional recurrence but penalize near-identical motion and framing. Store compact descriptors, not hours of video. A 2-hour history at one 64-byte descriptor/second is about 450 KiB before indexing overhead.

Fingerprints diagnose repetition; they do not command abrupt live changes. Adjust the next eligible phrase/episode when similarity remains high. If no valid novel scene is available, hold a good composition, mutate a meaningful action, and record library exhaustion rather than using arbitrary noise.

The library's authoring contract requires at least three episode scripts, three composition templates, and two transformation paths per initial family. Their combinations must be reviewed for meaningful differences. Counting palette permutations is not evidence of content variety.

## 20. Automatic art-direction system

“Generate Visual Identity” should compile a complete, reviewable creative proposal with staged progress:

1. **Inspect coverage:** identify usable audio, existing analysis, metadata, source limitations, and user locks.
2. **Analyze the program:** produce track summaries, ordered boundary relations, stylistic clusters, and likely chapters.
3. **Choose a direction:** score curated directions against the program and requested mood; avoid deterministic genre stereotypes.
4. **Instantiate DNA:** choose glyph rules, palette paths, motifs, typography, motion grammar, and safety limits.
5. **Compose the visual score:** assign episodes and structural cues; create neutral behavior for uncertain intervals.
6. **Plan bridges and reading:** allocate transitions, metadata windows, carrier continuity, and fallback scenes together.
7. **Validate:** enforce glyph support, parameter ranges, resource limits, safety eligibility, and title readability.
8. **Preview representative moments:** opening, quiet passage, structural contrast, callback, and one actual track boundary where available.
9. **Present the identity:** name, concise artistic rationale, analysis coverage, and three meaningful alternatives at most.

A deterministic constraint solver with a curated library is sufficient for the baseline. Optional AI can suggest a bounded direction choice or human-readable rationale, but it cannot write arbitrary runtime shaders, bypass the schema, fabricate analysis, or decide frame-by-frame behavior.

Use an initial candidate utility of 30% musical suitability, 25% DNA coherence, 20% composition, 15% recent novelty, and 10% continuity. These are tunable heuristics, not validated perceptual scores. Hard safety, availability, and resource constraints remain outside the weighted sum. Build only a small bounded candidate set; do not run repeated paid inference looking for a lucky result.

**First success:** Immediately offer a prepared starter direction and usable autonomous preview. Then replace future cues with progressively available analysis. Status must distinguish “preview ready” from “full playlist analyzed.” Do not block first use on analyzing hours of music, and do not silently replace a user's accepted current scene when deeper analysis completes.

Generation yields a draft that can be accepted, duplicated, or compared. Cancellation retains the previous accepted identity. Retrying reuses completed analysis and prepared assets. A failed optional classifier leaves a complete DSP-directed proposal with limited semantic claims.

Required explanation example: “Sparse architecture, long holds, and a returning arch connect the playlist's quiet passages. Faster tracks use precise local mechanisms rather than brighter frames. Seven of nine tracks have audio analysis; the remaining two use the same identity with autonomous timing.”

This explanation must derive from actual selected rules and coverage. Decorative AI prose is not a substitute for a score.

## 21. Guided controls

The default creative panel should expose a small set of intelligible decisions. Values are constrained macros over the underlying DNA; their effect must be visible without understanding FFT bins or render passes.

| Control | User-facing options | Behavior |
|---|---|---|
| World | A few curated direction previews | Changes family mixture, motifs, material logic, and composition together |
| Performance | Contemplative → Expressive → Dramatic | Changes event salience, pacing, and transformations within safety limits |
| Detail | Sparse → Layered → Intricate | Changes population and internal structure, not metadata font size |
| Color | Monochrome, restrained accents, richer terminal palette | Chooses an approved color grammar |
| Characters | Strict ASCII, Terminal, Expanded | Changes art vocabulary with meaningful family substitutions |
| Motion | Still, gentle, active | Changes amount/travel of animation independently of detail |
| Glitch | None, occasional, expressive | Adjusts eligible corruption events, not unrestricted flashes |
| Titles | Quiet, environmental, transformed | Chooses reading treatment and timing defaults |
| Camera | Locked, composed movement, more exploratory | Adjusts allowed shots; no perpetual motion requirement |

Keep the first visible set to World, Performance, Detail, and Color; place the other guided controls in a clearly labeled refinement area. Accessibility choices are always easy to find and never hidden inside “Advanced.”

World changes can require a prepared episode; continuous knobs should respond promptly through smoothing. Display “applies at next phrase” when a change is quantized, with an option to apply through a short safe transition now. Never imply a delayed change has already taken effect.

“More like this” preserves the direction and changes an unlocked composition seed. “Another direction” produces a new DNA draft. These are distinct from “Reset,” which restores a documented reference state.

## 22. Advanced controls and live experimentation

Advanced controls include scene-family inclusion and weights; per-family dwell ranges; motif selection; glyph subgroups; palette roles and paths; response source/envelope/range; event thresholds and cooldowns; frequency-band definitions; camera templates; transition eligibility; metadata fields/layouts; branding; seed policy; and parameter locks.

Expose mappings as typed rows with signal, response curve, target, amount, and preview feedback. A node editor or arbitrary scripting language is not necessary for the first implementation. Advanced creators need precision, not compulsory programming.

Every parameter defines one of four update policies:

- **Continuous:** change through a bounded ramp, normally visible within 100 ms on a healthy device; final settling may take longer by design.
- **Phrase-boundary:** show the staged value and its activation cue.
- **Scene-boundary:** prepare a replacement episode with a compatible exit.
- **Rebuild-required:** regenerate resources off the render/audio paths, retaining current output until ready.

All user edits are reversible transactions. A slider drag is one undo step; automation samples are not thousands of undo steps. Undo restores the setting and ramps from the current visual state—it does not rewind the live broadcast. Reset parameter restores the accepted preset value; reset section does the same for one inspector group. “Revert to generated identity” restores the generation snapshot. Label these different scopes explicitly.

Comparison uses the same audio interval and score time with two preset revisions, so viewers compare direction rather than different song moments. Prefer cached representative previews or sequential rendering when dual rendering would threaten program performance. Favorites and duplicate presets are local creative actions that never alter the currently active program automatically.

**While live:** Default experimentation to an audition draft, using the OBS-like preview/program separation described earlier. “Apply” commits a prepared change at its declared boundary. An explicit “Edit live” mode allows direct bounded control with an unmistakable status. In ordinary offline preview, edits apply immediately where feasible. This distinction protects the program without adding confirmation dialogs for every knob.

Creator-only controls, selection handles, warnings, and focus outlines must never enter the broadcast texture. A low-cost “Hold scene” freezes the current visual composition while audio continues; distinguish it from transport pause. Releasing hold rejoins the score through a safe transition and drops expired transient events.

Conceptual workspace responsibilities: Preview presents the current output/draft; Playlist and Now Playing supply track context; Scene edits the current family; Visual DNA edits persistent identity; Effects edits mappings; Output previews framing; Stream Health consumes renderer health. Phase 2 decides navigation and platform layouts.

## 23. Preset architecture

A preset is portable declarative data, not executable content. Separate four artifacts:

| Artifact | Contents | Portability |
|---|---|---|
| Visual preset | DNA defaults, overrides, locks, mappings, typography, family requirements | Import/export and share |
| Compiled visual score | Specific track/section assignments, cues, transition plans, analysis references | Regenerated when inputs change; optional session export |
| Runtime checkpoint | Current episode state, clocks, random counters, accepted edits, motif/history summaries | Local recovery/replay; version constrained |
| Prepared asset cache | Glyph atlases, geometry resources, derived previews | Disposable; rebuildable from versioned sources |

Preset package contract: versioned UTF-8 manifest; stable ID and revision; creator-visible name/description; minimum engine/content versions; declared capabilities; bounded parameter/mapping lists; fixed-width hexadecimal seeds; palette and typography roles; asset references with hashes and permissions provenance; and a preview thumbnail where available.

Save and duplicate are atomic: an accepted revision remains available if serialization fails. Autosaved working changes are separate from named presets. Export includes only explicitly chosen creative assets. Track PCM, private filesystem paths, account data, stream destinations, and keys do not belong in a visual preset.

Import validation rejects unknown executable content, path traversal, unsafe archives, excessive sizes, nonfinite numeric values, recursive/unbounded definitions, unsupported glyphs, and missing required resources. Newer unsupported schemas open as an explained incompatibility; do not silently reinterpret them. Known migrations preserve the original and write a new revision.

Missing optional assets can use declared substitutes with a visible comparison. Missing essential assets prevent activation while the current program continues. Imported presets always pass through the active accessibility and resource envelope; they cannot switch those protections off.

Do not include arbitrary downloaded shaders or remote URLs that are fetched during rendering in version 1. Expanding the extension model is a separate future security/performance decision.

## 24. Accessibility requirements

Accessibility applies to the creator workspace **and** the generated frames. A beautiful controller around an unsafe or unreadable broadcast does not satisfy this contract.

### 24.1 Motion and visual comfort

Honor system Reduce Motion in the control interface and local preview. For a new identity, default the broadcast motion profile to the same preference, while exposing a distinct persistent “Broadcast motion” setting. Changing the device preference during a live show should immediately calm the local view without silently rewriting the remote program. The saved broadcast profile remains explicit.

Reduced-motion episodes preserve scene meaning through static compositions, local small actions, and slow changes of state. Disable camera travel, roll, shake, tunnels, aggressive parallax, full-field displacement, and trails. Offer a still-preview mode with manual frame refresh for creators who want to direct animated output without continuously viewing it.

Test native controls with Reduce Motion and hardware keyboard access, following Apple's accessibility testing guidance. [Apple system accessibility testing](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)

### 24.2 Photosensitivity Safe mode

Provide the requested **Photosensitivity Safe** mode, enabled by default for generated identities. Explain its behavior as “Suppresses flashing, rapid brightness changes, and intense repeating patterns.” Do not claim medical certification or guarantee safety for every viewer, display, viewing distance, or platform transcode.

This is a stricter authored/rendered-content policy than merely disabling named strobe effects:

- No intentional strobe, rapid palette inversion, saturated-red flashing, blink loops, alternating high-contrast bars/checkers, or full-field impact flashes.
- No safety reliance on a flash occupying a supposedly small area; remote viewing size is unknown.
- Replace luminance accents with contour, shape, local displacement, or a single slow state change.
- Restrict scene, camera, and glyph-update combinations to validated conservative variants.
- Require a slow monotonic ramp of at least one second for large-area brightness changes as an initial authoring minimum; this alone is not proof of safety.
- Rate-limit cumulative local and global luminance reversals across all layers, including metadata entry, transitions, imported graphics, quality changes, and failure recovery.
- Exclude unvalidated animated external media from this mode. Still artwork is introduced under the same transition constraints.

W3C's flash guidance concerns opposing luminance changes, red flashes, frequency, and affected visual area—not average frame brightness alone. Its three-flash rule is a ceiling for relevant content, not a creative target. [W3C flash threshold guidance](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html)

**Required output guard:** Evaluate candidate output after composition and color conversion, before publication. Maintain a rolling history in presentation-time units, with spatially localized luminance/red-transition measurements. Reductions must conservatively preserve extrema and affected area; downsampling must not average alternating patterns into apparent safety. Also inspect high-contrast periodic structure and motion, which a global flash counter misses.

Use GPU-computed acceptance data in the same ordered command sequence to select the candidate or a safe replacement; do not publish first and wait for a later CPU diagnostic. Reject candidates that violate the conservative policy. Hold the last accepted frame, then enter a verified slow neutral tableau if suppression persists. The replacement path is also checked. Never recover by alternating black and the candidate frame.

The guard algorithm, its temporal thresholds, and spatial bounds are a **prototype/release gate**, not an already-solved guarantee. Until it is independently validated, restrict output to conservative scene variants and do not market compliance. A guard that misses tiny high-contrast glyphs or cannot run within budget blocks this mode's release claim.

Ordinary mode still suppresses dangerous flashing and validates output; safe mode adds more conservative motion, pattern, and effect restrictions. Advanced presets cannot bypass mandatory flash protection. Independent analysis of encoded test sequences is required because rasterization, frame drops, and compression can change the visible result.

### 24.3 Reading and interaction

Use the protected typography behavior and contrast targets from Section 18. Increase Contrast affects controls and offers an explicit broadcast-text variant. Reduce Transparency uses opaque control surfaces and solid reading backplates where appropriate.

Dynamic Type resizes controls and inspector layouts; it does not resize output text without the broadcast typography control. Provide meaningful labels, values, hints, and reset actions for every adjustable parameter. Visual sliders also have accessible increment/decrement and editable numeric alternatives.

VoiceOver should expose track, scene name, a concise authored scene description, active mode, and current editing state. Do not announce individual art glyphs or every beat. Status announcements are coalesced and avoid interrupting music constantly. Optional richer scene descriptions are on demand; autogenerated descriptions must not claim events that are not present in scene state.

All essential edits support keyboard, Voice Control, and standard accessibility actions usable by Switch Control. Provide clear focus, labeled commands, and alternatives to drag-only interaction. Use at least 44×44-point touch targets as a product target on iPhone/iPad; macOS may use denser native controls while retaining visible focus and usable hit areas. Test localized layouts, including right-to-left text and large accessibility sizes.

Color never acts as the only indication of selected state, confidence, live/draft status, or health. Artwork color distinctions also receive shape/density alternatives where they communicate an intended event.

## 25. Performance considerations

Build for sustained operation, not a short maximum-quality demo. Hardware/OS support and allowable continuous execution are Phase 2 decisions; the engine must expose measured capability instead of promising 4K on every Apple device.

| Technology | Proposed responsibility | Boundary/tradeoff |
|---|---|---|
| Swift | Score compiler, typed controls, deterministic director, resource ownership | Keep allocation and blocking work away from real-time paths |
| SwiftUI | Native workspace and inspectors | Never create one view per glyph or drive the render loop through view updates |
| Metal / Metal compute | Geometry/field evaluation, cell assignment, glyph rasterization, bounded effects, safety reductions | More specialized work, but direct control over cost and memory |
| Accelerate/vDSP | Fast audio features and array operations | Prefer this to ML for measurable signals |
| AVFoundation / Core Audio | Timed audio/transport handoff from the later playback system | Source-specific access and mixing remain Phase 2 |
| Core Text/native shaping | Readable metadata and font fallback; prepared glyph resources | Layout on metadata changes, not every frame |
| Core Image | Optional bounded artwork preparation or explicitly profiled finishing | Avoid hidden conversion/copy chains and overlapping Metal functionality |
| Core ML | Optional offline/low-rate semantic classifiers | Model licensing, conversion, accuracy, and thermal cost must be validated |

Render primarily offscreen. A visible Metal view is a consumer, not the owner of program progress; Apple distinguishes rendering into an intermediate texture from rendering into a drawable. [Apple render-pass setup](https://developer.apple.com/documentation/metal/customizing-render-pass-setup)

### 25.1 Initial quality profiles

| Profile | Candidate output | Character grid range | Content allowance |
|---|---|---|---|
| Essential | 1280×720 at 30 fps | Around 128×36 to 160×45 | One full world, light transition partner, no expensive feedback |
| Standard | 1920×1080 at 30 fps | Around 160×45 to 240×68 | Two bounded scene slots, limited atmosphere/history |
| Fluid | 1920×1080 at 60 fps where sustained | Same art grid as Standard | Smoother sampling, not twice the detail/effects |
| Large | 2560×1440 at 30 fps | Around 192×54 to 320×90 | Greater canvas fidelity; optional additional distant detail |
| Ultra | 3840×2160 at 30 fps; 60 fps experimental | Around 240×68 to 480×135 | Only benchmarked devices; crisp larger glyphs remain valid |

Resolution and glyph density are independent. A 4K image may intentionally use a 160×45 art grid with beautifully rasterized large characters. Broad scene design should survive a coarser grid.

At 30 fps the frame interval is 33.3 ms; at 60 fps it is 16.7 ms. Initial engine targets are p95 GPU time ≤60% of that interval and p99 ≤80%, leaving room for output consumers and contention. Target p95 director/CPU preparation below 2 ms per frame on the declared minimum supported hardware. These are profiling gates, not claimed results.

Plan a bounded memory budget before each profile is accepted. One 4K BGRA8 surface is about 31.6 MiB; one 4K RGBA16Float surface about 63.3 MiB. Multiple output buffers plus two full-resolution float histories can consume hundreds of MiB before scene resources. Prefer packed cell data, shared pools, low-resolution history, and transient texture reuse. Do not assume “ASCII” makes pixel output free.

### 25.2 Graceful scaling

Degrade in this order: remove secondary atmosphere → shorten optional histories → reduce offscreen material resolution → simplify distant geometry → choose a simpler family variant → coarsen non-text art grid at a stable boundary. Maintain the focal action, metadata, safety guard, and media clock throughout.

Keep the negotiated output dimensions, color format, and frame cadence stable during a live session. If the current output contract becomes unsustainable, report an explicit downgrade request to Phase 2; do not silently alter encoder inputs. Short overruns reuse safe visual content with a new timestamp, while simulation advances coherently. Sustained failure selects a lightweight tableau.

Initial governor: reduce a cost level after sustained overload for roughly two seconds; wait at least 30 seconds of stable headroom before considering an upgrade at an episode boundary. Immediate critical resource pressure can choose the fallback without waiting. Apply hysteresis to avoid oscillating quality. Record governor decisions for replay.

Precompile shaders and prewarm atlases off the active render path. Use bounded in-flight resources, normally two or three frame slots. Never let a slow preview or output consumer create an unbounded queue. Profile on real devices under sustained load, not only the simulator.

Apple GPU capabilities vary by family; choose features using actual support and profiling rather than an assumed common maximum. No baseline requirement for ray tracing, Metal 4-only features, or device-specific shader conveniences. [Apple Metal capability tables](https://developer.apple.com/metal/capabilities/)

## 26. Proposed rendering pipeline

The visual subsystem should implement the following logical flow. This is a renderer boundary design, not the complete app architecture.

```text
Permitted audio / cached features + typed transport events
                         │
             Timestamped analysis timeline
                         │
           Playlist DNA + compiled visual score
                         │
            Deterministic performance director
                         │
             Scene state and typed music ports
                         │
     Semantic geometry / direct glyph constructions
                         │
    Ownership, depth, material, salience, title masks
                         │
       Glyph selection + bounded glyph-space effects
                         │
       Metal atlas rendering + color-managed finishing
                         │
          Protected metadata / broadcast typography
                         │
       Final output conversion + temporal safety guard
                         │
            Timestamped accepted frame lease
                  ┌──────┴──────┐
          Creator preview   Phase 2 output consumer
```

### 26.1 Clock and scheduling

Use audio/media presentation time as the authority. Features, cues, edits, frame requests, and checkpoints refer to that same timeline plus a transport epoch that changes on discontinuities. UI wall time and display refresh do not decide musical phase.

Advance deterministic scene logic at a fixed simulation step, initially 120 Hz for lightweight state, or evaluate analytic curves directly at requested time. Expensive simulations can use a documented lower fixed rate. Render interpolation does not trigger new events. A 30 fps and 60 fps output should produce equivalent event decisions.

Do not catch up indefinitely when delayed. Limit incremental catch-up work, then reconstruct from score/checkpoint or switch to a prepared safe state. Deduplicate events by ID and epoch. Expired transients are dropped; structural state changes are applied once or reconstructed.

Timestamp precision uses integer sample indices/rational times. Quantize or bound simulation values where required. Record random algorithm/version, seeds, content versions, analysis revision, user edits, and quality decisions.

### 26.2 Work separation

Audio callbacks only hand off preallocated bounded sample/timing data. They do no file IO, shader compilation, model inference, texture allocation, UI mutation, or waiting on rendering. Analysis occurs on a worker; overload drops/coalesces analysis work with coverage diagnostics rather than blocking playback.

The director publishes immutable render snapshots through a bounded handoff. GPU resources are prepared separately and activated only when ready. UI commands carry revisions and effective times, so concurrent edits cannot partially mutate the frame being rendered. A single logical authority owns score state; Phase 2 can choose the precise Swift concurrency mechanism.

Rendering into a shared pixel-buffer-backed Metal texture is a candidate output path. `CVMetalTextureCache` supports creating Metal texture views of Core Video image buffers; actual format support, conversion costs, synchronization, and encoder compatibility must be measured. Do not claim universal zero-copy behavior. [Apple CVMetalTextureCache](https://developer.apple.com/documentation/corevideo/cvmetaltexturecache-q3j)

### 26.3 Frame ownership and failure

The renderer returns an accepted frame with PTS, duration, dimensions, color description, revision IDs, GPU-completion readiness, and an ownership lease. Consumers must not access incomplete work or recycle memory still in use. A pool caps outstanding leases; a stalled consumer triggers a dropped/held frame policy, not unlimited allocation.

Preview may skip frames and resize independently without changing program state. Closing a preview window does not stop offscreen rendering while the host permits execution. Encoders, networks, reconnect logic, and destination handling are outside this phase.

Recoverable engine faults produce specific diagnostics such as “Incoming scene could not prepare. The current scene is continuing,” or “Audio analysis is delayed. Visuals are using the last stable tempo.” Invalid parameters preserve the prior revision. Shader/resource failure selects a tested simplified scene; inability to produce frames emits an explicit hard failure to the output owner.

Checkpoint at episode boundaries and periodically, initially every five seconds, with atomic replace. Store bounded scene state, PRNG counters, cue cursor, transport mapping, active preset revision, motif ledger, and compact anti-repetition history. Large GPU feedback state is either checkpointed within a declared budget or reconstructed through a bounded preroll. If exact recovery is unavailable, use a designed dissolve into a recovered semantic state and disclose the replay limitation.

Recovery restores a previewable visual session. It does not authorize automatically resuming a public broadcast after application relaunch; Phase 2 owns that user decision.

## 27. Deterministic versus ML-generated components

| Component | Baseline decision | Why / tradeoff |
|---|---|---|
| Spectral features and envelopes | Deterministic DSP | Fast, explainable, local, no model needed |
| Beat/tempo and recurrence | Deterministic baseline; compare optional learned estimators | DSP permits a useful floor; harder material may justify better models |
| Section identity A/B/A′ | Feature recurrence and novelty with confidence | Useful without claiming a semantic song form |
| Chorus/verse/drop labels | Optional inference only | Music structure is not universally named or reliably obvious |
| Genre/mood/instrument/vocal labels | Optional local model or supplied metadata | Adds priors; uncertain and training-domain dependent |
| Playlist clustering | Deterministic features; optional embeddings | Preserves operation when ML unavailable |
| DNA and score compilation | Deterministic constrained selection | Reproducible, inspectable, no generative API in critical path |
| Scene geometry, entities, motion, glyphs | Authored procedural systems | Persistent, bounded, responsive, recoverable |
| Per-frame output | Metal rendering only | No diffusion/video-generation latency or per-frame cost |
| Preset names/rationales | Templates by default; optional bounded language assistance | Does not gate preview or operation |
| Bespoke external assets | Optional future authoring input | Must be persisted, licensed, validated, and available before activation |

Core ML is an execution option, not a ready-made music-understanding model. Sol must evaluate candidate weights, commercial licensing, input preprocessing, conversion correctness, latency, memory, and cross-genre accuracy. For example, Essentia documents useful music models but states licensing conditions that cannot be assumed suitable for commercial bundling; it is a research candidate, not an adopted dependency. [Essentia model catalog and licensing](https://essentia.upf.edu/models.html)

No cloud service is required to keep the show running. Optional analysis is cached by audio fingerprint + preprocessing + model/version. Avoid repeating inference on every playback and never invoke a paid model per beat or frame. Source separation is not a baseline dependency: it adds cost and may produce artifacts without being necessary for compelling direction.

**Determinism levels:** Require identical event/scene decisions from the same recorded inputs and versions. Aim for close visual replay within a pinned device/quality environment. Do not promise bit-identical GPU pixels across OS, hardware, fonts, compiler, or quality changes. Golden-frame tests use declared tolerances; CPU event traces use exact equality. A portable replay bundle must include or identify all required versions and licensed assets.

## 28. Technical and creative risks

| Risk | Consequence | Mitigation and decision gate |
|---|---|---|
| Too little authored dramatic content | A sophisticated renderer still looks like a loop collection | Require distinct action/topology models and long-form viewing tests before library expansion |
| Weak analysis on atypical music | Wrong cuts, false climaxes, rhythmic discomfort | Confidence routing, free-time scenes, manual markers, cross-genre corpus |
| Beat ambiguity/latency | Visuals emphasize the wrong moment | Timestamped features, alternative tempo hypotheses, no forced bar grid |
| “ASCII filter” aesthetic | Product lacks a distinctive medium | Direct glyph constructions, semantic materials, recognizable negative-space scenes |
| Temporal glyph chatter | Shimmer, fatigue, poor compression | Hysteresis, stable sampling/dither, minimum glyph sizes |
| Compression destroys detail | Attractive preview becomes unreadable stream | Encode/decode prototypes at constrained budgets; simplify glyphs and color |
| Safety guard incomplete | Unsafe patterns can survive effect restrictions | Conservative library, same-frame guard, independent output analysis before release claims |
| Color/metadata failures | Artist information unreadable or inaccurate | Shaped text, protected masks, fallback layouts, source provenance |
| Anti-repetition overcorrection | Constant novelty removes identity or musical timing | Penalize repeated episode tuples, keep intentional motifs, only replan at valid boundaries |
| Crossfade feature conflicts | Doubled beats or confused musical attribution | Actual mix features and gain envelopes; explicit current-track policy |
| Resource contention/thermal pressure | Long sessions degrade despite good short demos | Sustained physical-device profiling, headroom, bounded queues, adaptive detail |
| Glyph grid changes pop | Quality adaptation breaks composition | Boundary-aligned adaptation and stable subject/text representation |
| ML licensing/domain limits | Unshippable or culturally narrow art direction | Keep baseline model-free; evaluate data and licenses before adoption |
| GPU nondeterminism/state recovery | Replays diverge or restore stalls | Versioned event traces, bounded checkpoints, designed approximate recovery |
| iOS/iPadOS suspension | Offscreen/continuous work may not run indefinitely | Phase 2 must verify foreground, background, lock, interruption, and thermal limits; a renderer design cannot promise unrestricted background broadcasting |
| Raw audio unavailable | Music-aware behavior cannot operate for that source | Capability-based modes and explicit coverage; no DRM bypass assumption |

The two largest creative risks are insufficient authored episode quality and constant motion masquerading as sophistication. Resolve those before scaling the renderer or adding ML.

## 29. Prototype experiments required

These are proposed experiments, not work executed in Phase 1. Each should produce a short recording, configuration/seed, exact device/build information where relevant, and a written result. Do not progress merely because a demo compiles.

| ID | Experiment | Evidence and decision |
|---|---|---|
| P1 | **Medium proof:** build the three detailed episodes from Section 8 with authored cues and simple permitted audio | Compare direct glyph construction, material-aware sampling, and a brightness-only ASCII baseline. Must show recognizable subjects/actions at small and large viewing sizes. If all look like filters, revise the medium before analysis work. |
| P2 | **Music proof:** test DSP/confidence routing on ≥30 licensed tracks, covering steady electronic, acoustic, jazz, ambient, orchestral, noisy, changing tempo, odd meter, silence, and mixed forms | Annotate beatable regions, salient boundaries, uncertainty, and rests. Measure onset/beat errors separately from director quality. Do not report an aggregate that hides entire failed categories. |
| P3 | **Structural direction:** compare full score, amplitude-only mappings, and the same score with shuffled structural cues | Blind viewers assess whether changes feel earned. Include incorrect/low-confidence boundaries to test restraint. Structural intelligence should improve preference without requiring perfect chorus labels. |
| P4 | **Playlist identity:** score contrasting 60–90-minute playlists with repeated and reordered tracks | Test recognizability, chapter contrast, meaningful callbacks, and edit stability. Detect whether identity collapses to palette alone. |
| P5 | **Compression:** render 720p/1080p/1440p/4K samples, then encode/decode using representative output budgets selected in Phase 2 | Inspect fine punctuation, Braille, pans, saturated text, and quiet scenes. Record text/contour loss; choose grid and stroke floors from the result. |
| P6 | **Timing/replay:** test 30/60 fps, seeking, skips, pause/resume, variable playback rate, overlap, delayed analysis, and dropped frames | Compare exact event logs, visual PTS, cue timing, and bounded recovery. Verify no duplicate onsets and no audio-thread waiting. |
| P7 | **Safety/accessibility:** test every eligible family/effect pair plus adverse parameter combinations and quality transitions | Independently inspect final and encoded frames for flashes/pattern hazards; audit readable titles and assistive control paths. Do not expose photosensitive participants to unvalidated stimuli. Specialist review precedes any such user research. |
| P8 | **Sustained budget:** run at least 8 hours on candidate minimum iPhone, iPad, and Mac hardware under realistic preview/output contention | Measure GPU/CPU tails, memory slope, temperature/thermal state, frame misses, lease backlog, and quality interventions. Establish actual per-device profiles. |
| P9 | **Variation:** run an 8-hour score with repeats, a small library, fixed seeds, and intentional callbacks | Compare output fingerprints and human time-scrubbing judgments. Ensure the system can report exhausted variety instead of hiding it with random effects. |
| P10 | **Creative control:** ask novice creators to generate, alter, compare, undo, duplicate, and restore a preset while a program continues | Measure first acceptable identity, understanding of live/draft, undo success, and accidental changes. Revise controls that require technical explanations. |
| P11 | **Optional ML value:** compare one commercially viable candidate with the DSP-only baseline | Adopt only if blinded direction quality improves enough to justify model footprint, analysis time, integration and maintenance cost. Higher classifier accuracy alone is insufficient. |

Recommended execution order: P1 → P2/P3 → P5/P7 → P4/P9 → P6/P8/P10 → P11 if needed. Safety and performance instrumentation begin with the first prototype even where full validation comes later. The vertical slice is one identity, three deep families, two transitions, opening/closing titles, conservative mode, permitted local audio, and deterministic replay. It does not require source integrations or livestreaming.

## 30. Criteria for engaging rather than merely reactive

Engagement cannot be proven by a shader benchmark or an arbitrary “visual complexity” score. Use objective technical gates plus preregistered comparative viewing studies. The targets below are proposed product gates and must not be represented as achieved.

### 30.1 Non-negotiable technical gates

| Dimension | Initial acceptance target |
|---|---|
| Synchronization | For pre-analyzed, high-confidence cues, p95 error ≤50 ms relative to the negotiated audible timeline; separately report causal-analysis latency and display/output latency |
| Stability | In an 8-hour supported-profile run, no unbounded queue or resource growth; after warmup, comparable workload memory changes by <5%; no renderer crash |
| Frame budget | Meet Section 25 p95/p99 budgets; renderer-caused deadline misses <0.1% and no repeated burst of >3 misses in healthy supported conditions |
| Deterministic decisions | Identical scene/cue event trace for a fixed input recording, preset, content versions, and quality-decision log |
| Typography | Title and artist available through required windows; ≥95% correct transcription in a small-window reading task on supported layouts; no scripted language group hidden by aggregate results |
| Safety | No violations under the chosen independently verified flash-analysis procedure for the release corpus; adversarial transitions and fallbacks included; no claim of universal medical safety |
| Graceful failure | Missing audio features, unknown duration, scene preparation failure, and consumer stalls all produce specified fallback behavior without blocking the playback boundary |
| Recovery | Valid checkpoint restores editable preset, score identity, motif state, and a bounded visual recovery path; corrupt newest checkpoint falls back to the prior valid revision |

### 30.2 Comparative creative evaluation

Use the same licensed audio, output resolution, average visual intensity, metadata, and acceptable safety profile across conditions. Randomize and counterbalance presentation order. Include at least an amplitude-reactive ASCII baseline, a well-composed single-scene baseline, and the proposed scored engine. Add an ablation with structural cues shuffled while micro-response remains aligned.

Run an initial formative study with 12–20 participants, then a larger preregistered study sized from observed variance; a convenience sample is not conclusive market validation. Include both casual listeners and experienced visual creators. Collect within-person differences and uncertainty intervals, and report genre/experience subgroups without fishing for favorable slices.

Proposed launch-direction gates:

- **Preference:** At least 65% prefer the scored engine over the stronger baseline for keeping on a screen, with the confirmatory interval supporting a real advantage over chance.
- **Extended use:** Median voluntary viewing/background-screen continuation rises by at least 20% against that baseline in a controlled 20–30-minute choice task. Track “left visible” separately from “actively watched.”
- **Musical consequence:** On a seven-point rating, structural changes average at least one point above shuffled-cue control for feeling related to the music. A beat-aligned pulse alone should not pass this test.
- **Identity:** At least 75% correctly match held-out clips to one of three learned playlist identities when channel text is hidden. Repeat in grayscale to test more than palette recognition.
- **Narrative legibility:** At least 70% can describe a meaningful action or transformation from a one-minute episode without being told the intended story. “Particles moved” or “it flashed with the beat” does not count as an authored action.
- **Pacing:** At least 80% rate the 30-minute program as suitable for continued display; report fatigue and reasons for hiding it. No advantage in spectacle scores can cancel a worse fatigue result.
- **Repetition:** Fewer than 20% report an obvious short visual loop in a 30-minute sample; intentional callbacks should be described as returns or developments, not identical replay.
- **Automatic quality:** At least 80% of novice participants accept one generated identity or one of its initial alternatives without advanced edits. Record reasons for rejection rather than inflating success through unlimited rerolls.

Behavioral preference and continuation are primary outcomes; self-report, identity recognition, and fingerprint statistics explain them. A system can pass technical gates and still fail this product test.

If the full engine does not beat the composed single-scene baseline, simplify direction and improve authored episodes before adding families or more effects. If micro-response wins but structural cues do not, revisit cue confidence and musical timing. If identity recognition is high but repetition complaints rise, vary actions and consequences rather than changing the branding.

## 31. Concrete handoff contract for GPT-5.6 Sol

Sol should incorporate this specification into Phase 2 as the visual subsystem's requirements. It should not treat the catalogue as a request to implement the entire app during this phase.

### 31.1 Preserve these decisions

1. Playlist DNA compiles into a visual score with persistent entities and four temporal scales.
2. Direct glyph constructions and material-aware glyph rendering form the medium; a brightness filter is insufficient.
3. Deterministic DSP, confidence-aware directing, and authored procedural families form a complete baseline without cloud generation.
4. Structural identities A/B/A′ remain separate from uncertain semantic labels such as chorus.
5. The initial prototype proves three deep scene episodes before expanding the library.
6. Metadata has approximately first/final ten-second windows, protected reading time, native script support, and short/unknown-track policies.
7. Safety applies after full composition and color conversion; safe mode restricts the allowed content as well as validating it.
8. Offscreen rendering, bounded queues, explicit PTS, and ownership leases decouple the show from UI refresh and slow consumers.
9. Live experimentation uses reversible drafts or an explicit direct-edit mode.
10. Source capability and rights are supplied by the later product architecture; visualization never assumes audio access from metadata access.

### 31.2 Required data contracts

These are conceptual field requirements, not Swift code or a final database schema. All IDs are stable strings; times use integer/rational media time, never locale-formatted text; unknown values are explicit null/unknown states rather than zero.

| Contract | Required fields and invariants |
|---|---|
| `AudioAccessDescriptor` | Source reference, permitted analysis capability, PCM/feature availability, channels, sample rate, duration if known, coverage intervals, restrictions/provenance reference. It does not grant rebroadcast rights. |
| `TransportSnapshot` | Transport epoch, media PTS, sample position/rate, playback rate, play/pause state, current track instance, next track if known, actual overlap/gain envelope, discontinuity reason. |
| `FeatureFrame` | Epoch, audio interval, presentation reference, analysis latency/lookahead, raw and normalized values, valid flags, confidence/provenance, extractor version. Missing data is not a silent zero. |
| `MusicalEvent` | Stable event ID, epoch, kind, timestamp/interval, strength, confidence, evidence references, optional beat/section identity. Duplicate IDs cannot retrigger. |
| `TrackAnalysis` | Audio fingerprint/reference, preprocessing and estimator versions, duration, coverage, feature statistics, tempo hypotheses, section graph/recurrence, optional tags, manual overrides. |
| `ProgramAnalysis` | Ordered track instances, duration and coverage summaries, trajectories, soft clusters, adjacency compatibility with coverage, recurrence links, chapter candidates. |
| `VisualDNA` | ID/revision, seed algorithm/version, palette/glyph/motion/camera/typography rules, family weights, motif definitions, pacing/variation constraints, locks, capability requirements. |
| `VisualScore` | DNA and analysis revisions, track/section episode assignments, cue list, transition plans, title reservations, confidence fallbacks, bounded planning/commit horizon. |
| `SceneManifest` | Family/version, typed parameters, dramatic actions, resource cap, title anchors, carriers, safety eligibility, quality variants, checkpoint schema. |
| `RenderSnapshot` | Epoch/time, accepted revision, active episode state, semantic control channels, active gestures, title layout reference, quality and safety profile, deterministic random keys. |
| `FrameLease` | PTS/duration, dimensions/pixel format, primaries/transfer/matrix/range, frame/revision IDs, completion readiness, accepted safety status, bounded ownership/release obligation. |
| `EngineHealth` | Frame-time distributions, missed deadlines, memory/pool occupancy, feature age/coverage, preparation failures, active quality, safety suppression, explicit recoverable/hard status. |
| `VisualCheckpoint` | Schema/content versions, epoch-to-session mapping, cue cursor, scene state, seeds/counters, accepted edit revision, motif/history summaries, optional bounded temporal-state reference. |

### 31.3 Example preset manifest

The following is illustrative declarative data for the proposed schema. It references authored families defined above; those assets and an executable schema do not yet exist.

```json
{
  "schemaVersion": 1,
  "presetID": "night-transit-example",
  "revision": 1,
  "name": "Night Transit",
  "engineContract": "visual-score-v1",
  "seed": "000000000000bc8f",
  "seedAlgorithm": "versioned-named-streams-v1",
  "artGlyphProfile": "strict-ascii",
  "metadataTextPolicy": "native-script-shaped",
  "families": [
    { "id": "folded-city", "weight": 0.50 },
    { "id": "weaving-engine", "weight": 0.30 },
    { "id": "negative-space-theatre", "weight": 0.20 }
  ],
  "motifs": [
    { "id": "split-arch", "invariant": "one-missing-cell", "carryAs": "frame" }
  ],
  "paletteDirection": "ink-ivory-muted-signal",
  "camera": { "mode": "composed", "roll": false, "shake": false },
  "pacing": {
    "episodeSeconds": [24, 90],
    "majorRevealCooldownSeconds": 45,
    "quietFractionTarget": [0.20, 0.35]
  },
  "titles": {
    "openingSeconds": 10,
    "closingSeconds": 10,
    "fields": ["title", "artist"],
    "treatment": "environmental-with-quiet-fallback"
  },
  "transitionFamilies": ["frame-handoff", "negative-space", "glyph-reconstruction"],
  "requestedSafetyProfile": "photosensitivity-safe",
  "missingAnalysisBehavior": "autonomous-with-coverage-status",
  "locks": ["artGlyphProfile", "camera.roll", "camera.shake"]
}
```

The active host safety profile can make this preset more conservative. A manifest request never weakens mandatory output protection. Referenced symbolic palette/font/content IDs must resolve to versioned, validated resources before activation.

### 31.4 Example score passage

Hypothetical 240-second track with pre-analyzed, high-confidence boundaries. These times demonstrate the contract; they are not a universal song template.

| Time | Musical evidence | Visual instruction | Persistent state |
|---|---|---|---|
| 0–10 s | Track starts | Station sign shows title/artist; locked concourse shot | Introduce split arch and carriage |
| 10–40 s | Stable rhythmic section A | Small gate/stitch articulation; slow route assembly | Arch remains incomplete |
| 40–64 s | Rising density and reliable upcoming boundary | Compress local space; reduce camera activity; withhold opening | Store route and carriage position |
| 64–96 s | Confirmed contrasting section B | Unfold station into map; no flash | Same route and carriage become map objects |
| 96–128 s | Low activity / section C | Sparse negative-space tableau and long hold | Carriage becomes a cursor-like carrier |
| 128–176 s | Return of A with variation | Rebuild familiar concourse at a different scale | Earlier missing cell becomes a doorway |
| 176–214 s | Confirmed major recurrence/contrast | Observatory-style aperture reveal using the arch carrier | Preserve one illuminated window |
| 214–230 s | Falling activity | Settle into outgoing handoff composition | Window positioned at next scene's anchor |
| 230–240 s | Known ending | Return title/artist; quiet exit with protected reading | Next world prepared offscreen |
| Next boundary | Actual next-track event | Window becomes an archive lamp through a compatible bridge | Transfer carrier identity; retire prior scene |

If those boundaries are low-confidence, the score holds its current episode or makes a small phrase-level change. If the track is skipped at 112 seconds, all later cues are canceled and the carrier enters the next prepared/fallback world. If output quality drops, distant detail disappears while this causal sequence remains intact.

### 31.5 Phase 2 integration decisions and release gates

Sol must resolve the following without broadening this Phase 1 work retroactively:

- Which source adapters can provide permitted PCM, cached features, trusted transport time, and actual overlap envelopes.
- Minimum supported OS/hardware and measured sustained output profiles, including mobile lifecycle restrictions.
- Output pixel format, color metadata, buffer ownership, alignment delay, and frame cadence negotiated with playback/encoding.
- Native font/resource packaging and exact optional ML candidates, if any, after licensing and conversion review.
- Persistence/recovery ownership for the declared visual artifacts and compatibility policy across updates.
- Platform-appropriate control layout around the live/draft model and the existing product-wide accessibility requirements.

Before moving beyond the visual vertical slice, require P1's medium proof, P2/P3's musical proof, P5's encoded readability, and P7's conservative safety feasibility. Before claiming continuous-channel readiness, require the multi-hour identity/variation and sustained device tests. Before calling the experience compelling, require comparative viewing evidence from Section 30.

**The defining outcome to preserve:** music changes what the world does, phrases change what the world reveals, tracks change what the world becomes, and the playlist determines why those worlds belong together.
