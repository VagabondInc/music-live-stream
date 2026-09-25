//
//  VisualEngine.swift
//  ASCII Broadcast
//
//  Owns scene state and frame production. It is handed an immutable, time
//  aligned snapshot and returns one composed character frame. It never touches
//  the audio callback, the database, or the UI.
//
//  Render order (Phase 1 §9):
//  world -> ownership/depth -> glyph assignment -> transition composite ->
//  glyph-space effects -> protected reading text -> safety validation.
//

import Foundation

struct GlyphFrame {
    var columns: Int
    var rows: Int
    var cells: [GlyphCell]
    var palette: Palette
    var sceneIndex: Int = 1
    var sceneTitle: String = ""
    var sceneSlug: String = ""
    var chapterLetter: String = "A"
    var chapterTitle: String = ""
    var worldLabel: String = ""
    var glyphLabel: String = ""
    var renderLabel: String = "REALTIME"
    var activeTransition: TransitionKind?
    var safetyInterventions: Int = 0
    var fillFraction: Double = 0
    var isFreeRunning: Bool = false
}

final class VisualEngine {

    // MARK: - State

    private var grid: GlyphGrid
    private var gridOutgoing: GlyphGrid
    private var gridIncoming: GlyphGrid

    private var currentScene: SceneEpisode?
    private var outgoingScene: SceneEpisode?
    private var currentCue: ScoreSceneCue?
    private var outgoingCue: ScoreSceneCue?
    private var carrier: MotifCarrierState?

    private var vocabulary = GlyphVocabulary(profile: .terminal)
    private var palette = Palette.nightTransit
    private let safety = SafetyEnvelope()

    // Music port envelopes — separate rise and fall per Phase 1 §13.
    private var pressure = Envelope(attack: 0.035, release: 0.45)
    private var articulation = Envelope(attack: 0.008, release: 0.14)
    private var bodyEnvelope = Envelope(attack: 0.05, release: 0.35)
    private var airEnvelope = Envelope(attack: 0.01, release: 0.2)
    private var densityEnvelope = Envelope(attack: 0.4, release: 1.8)
    private var releaseEnvelope = Envelope(attack: 0.02, release: 1.6)

    private var frameIndex = 0
    private var lastSectionID: UUID?
    private var seenSectionLetters: [String: Int] = [:]
    private var sceneEntryTime: Double = 0
    private var freeRunCueIndex = 0

    private(set) var lastFrame: GlyphFrame?

    init(columns: Int = 240, rows: Int = 68) {
        grid = GlyphGrid(columns: columns, rows: rows)
        gridOutgoing = GlyphGrid(columns: columns, rows: rows)
        gridIncoming = GlyphGrid(columns: columns, rows: rows)
    }

    func resize(columns: Int, rows: Int) {
        guard columns != grid.columns || rows != grid.rows else { return }
        grid.resize(columns: columns, rows: rows)
        gridOutgoing.resize(columns: columns, rows: rows)
        gridIncoming.resize(columns: columns, rows: rows)
        if let cue = currentCue {
            currentScene?.prepare(cue: cue, dna: lastDNA, columns: columns, rows: rows)
        }
    }

    private var lastDNA = VisualDNA.starter

    func reset() {
        currentScene = nil
        outgoingScene = nil
        currentCue = nil
        outgoingCue = nil
        carrier = nil
        safety.reset()
        seenSectionLetters.removeAll()
        frameIndex = 0
    }

    // MARK: - Frame production

    struct Input {
        var programTime: Double
        var trackTime: Double
        var deltaTime: Double
        var features: FeatureFrame
        var score: VisualScore
        var dna: VisualDNA
        var analysis: TrackAnalysis?
        var channelName: String?
        var elapsedBroadcast: Double?
        var qualityTier: Int = 0
    }

    func render(_ input: Input) -> GlyphFrame {
        frameIndex += 1
        lastDNA = input.dna

        // 1. Vocabulary and palette follow the DNA, then accessibility.
        vocabulary = GlyphVocabulary(profile: input.dna.glyphProfile)
        var activePalette = Palette.authored(for: input.dna.direction)
        let drift = (Noise.fbm1D(input.programTime * 0.01, seed: input.dna.seed) - 0.5)
            * (Double(input.dna.controls.paletteDrift) / 100.0)
        activePalette = activePalette.adjusted(behaviour: input.dna.color,
                                               colorBlindSafe: input.dna.colorBlindSafe,
                                               drift: drift)
        if input.dna.photosensitivitySafe {
            activePalette = activePalette.photosensitivityLimited()
        }
        palette = activePalette

        // 2. Resolve the cue, possibly free-running.
        let cue = resolveCue(score: input.score, time: input.programTime, dna: input.dna)
        activateSceneIfNeeded(for: cue, dna: input.dna)

        // 3. Build the snapshot every scene reads.
        let snapshot = makeSnapshot(input: input, cue: cue)

        // 4. World evaluation, with a transition composite when bridging.
        let transitionCue = input.score.transition(at: input.programTime)
        let bridging = transitionCue != nil && outgoingScene != nil

        if bridging, let transitionCue, let outgoing = outgoingScene, let current = currentScene {
            let progress = clamp((input.programTime - transitionCue.start) / max(0.01, transitionCue.duration), 0, 1)

            gridOutgoing.clear()
            var outgoingSnapshot = snapshot
            if let outgoingCue { outgoingSnapshot.cue = outgoingCue }
            outgoingSnapshot.sceneTime = input.programTime - (outgoingCue?.start ?? 0)
            renderScene(outgoing, into: gridOutgoing, snapshot: outgoingSnapshot, tier: input.qualityTier)

            gridIncoming.clear()
            renderScene(current, into: gridIncoming, snapshot: snapshot, tier: input.qualityTier)

            grid.clear()
            TransitionEngine.composite(outgoing: gridOutgoing,
                                       incoming: gridIncoming,
                                       into: grid,
                                       kind: transitionCue.kind,
                                       progress: progress,
                                       seed: cue.seed,
                                       carrier: carrier,
                                       vocabulary: vocabulary)
            if progress > 0.995 { outgoingScene = nil; outgoingCue = nil }
        } else {
            grid.clear()
            if let current = currentScene {
                renderScene(current, into: grid, snapshot: snapshot, tier: input.qualityTier)
            }
            outgoingScene = nil
        }

        // 5. Glyph-space effects, masked by ownership and protected reading.
        let fxCues = input.score.activeFX(at: input.programTime)
        EffectSystem.apply(fxCues, to: grid, time: input.programTime,
                           snapshot: snapshot, vocabulary: vocabulary)

        // 6. Protected reading last, so nothing can overwrite a title.
        TitleLayer.render(into: grid,
                          cues: input.score.activeTitles(at: input.programTime),
                          time: input.programTime,
                          dna: input.dna,
                          vocabulary: vocabulary,
                          ports: snapshot.ports)
        TitleLayer.renderBranding(into: grid,
                                  channelName: input.channelName,
                                  elapsed: input.elapsedBroadcast,
                                  dna: input.dna,
                                  vocabulary: vocabulary)

        // 7. Mandatory safety validation before the frame can leave.
        safety.enforce(on: grid, palette: palette, dna: input.dna, deltaTime: input.deltaTime)

        let chapter = input.score.chapter(at: input.programTime)
        var frame = GlyphFrame(columns: grid.columns,
                               rows: grid.rows,
                               cells: grid.copyCells(),
                               palette: palette)
        frame.sceneIndex = cue.index
        frame.sceneTitle = currentScene?.episodeTitle ?? cue.episodeTitle
        frame.sceneSlug = cue.slug
        frame.chapterLetter = chapter?.letter ?? "A"
        frame.chapterTitle = chapter?.title ?? ""
        frame.worldLabel = input.dna.direction.description
        frame.glyphLabel = input.dna.glyphProfile.description
        frame.renderLabel = input.qualityTier == 0 ? "REALTIME" : "REDUCED \(input.qualityTier)"
        frame.activeTransition = transitionCue?.kind
        frame.safetyInterventions = safety.interventionCount
        frame.fillFraction = grid.fillFraction
        frame.isFreeRunning = snapshot.isFreeRunning
        lastFrame = frame
        return frame
    }

    // MARK: - Scene lifecycle

    private func renderScene(_ scene: SceneEpisode, into target: GlyphGrid,
                             snapshot: RenderSnapshot, tier: Int) {
        if tier >= 2 {
            scene.renderFallback(into: target, snapshot: snapshot, vocabulary: vocabulary)
        } else {
            scene.render(into: target, snapshot: snapshot, vocabulary: vocabulary)
        }
    }

    private func activateSceneIfNeeded(for cue: ScoreSceneCue, dna: VisualDNA) {
        guard currentCue?.id != cue.id else { return }
        // Hand the current episode's carrier to the next one before swapping.
        if let current = currentScene {
            carrier = current.exitCarrier()
            outgoingScene = current
            outgoingCue = currentCue
        }
        let scene = makeScene(for: cue.family)
        scene.prepare(cue: cue, dna: dna, columns: grid.columns, rows: grid.rows)
        if let carrier { scene.accept(carrier: carrier) }
        currentScene = scene
        currentCue = cue
        sceneEntryTime = cue.start
    }

    private func makeScene(for family: SceneFamily) -> SceneEpisode {
        switch family {
        case .foldedCity:           return FoldedCityScene()
        case .weavingEngine:        return WeavingEngineScene()
        case .negativeSpaceTheatre: return NegativeSpaceScene()
        }
    }

    /// When no score exists — first launch, demo mode, or analysis still
    /// running — the engine performs a capable free-running programme instead
    /// of inventing musical certainty.
    private func resolveCue(score: VisualScore, time: Double, dna: VisualDNA) -> ScoreSceneCue {
        if let cue = score.scene(at: time) { return cue }
        let period = 46.0
        let index = max(0, Int(time / period))
        if index != freeRunCueIndex || currentCue == nil {
            freeRunCueIndex = index
        }
        let families = Array(dna.weightedFamilies.keys).sorted { $0.rawValue < $1.rawValue }
        let family = families.isEmpty ? SceneFamily.foldedCity : families[index % families.count]
        var generator = SeededGenerator(seed: dna.seed &+ UInt64(index), stream: "free-run")
        let titles = family.episodeTitles
        let title = titles[generator.index(titles.count)]
        return ScoreSceneCue(index: index + 1,
                             family: family,
                             episodeTitle: title,
                             slug: ScoreCompiler.slug(index: index + 1, title: title),
                             start: Double(index) * period,
                             end: Double(index + 1) * period,
                             seed: dna.seed &+ UInt64(index &* 7919),
                             intensity: 0.5,
                             trackInstanceID: nil)
    }

    // MARK: - Snapshot

    private func makeSnapshot(input: Input, cue: ScoreSceneCue) -> RenderSnapshot {
        let dt = max(0.001, input.deltaTime)
        let features = input.features

        var ports = MusicPorts()
        ports.pressure = pressure.update(Double(features.pressure), dt: dt)
        ports.articulation = articulation.update(Double(features.articulation), dt: dt)
        ports.body = bodyEnvelope.update(Double(features.body), dt: dt)
        ports.air = airEnvelope.update(Double(features.highEnergy), dt: dt)
        ports.brightness = Double(features.centroid)
        ports.density = densityEnvelope.update(Double(features.onset) * 3.0, dt: dt)
        ports.impact = Double(features.onset)

        let section = input.analysis?.section(at: input.trackTime)
        var releaseTarget = 0.0
        if let section {
            if section.id != lastSectionID {
                lastSectionID = section.id
                seenSectionLetters[section.letter, default: 0] += 1
            }
            // A section arrival is an impulse, not a level.
            let entryProgress = clamp((input.trackTime - section.start) / 1.2, 0, 1)
            releaseTarget = (1 - entryProgress) * section.kind.spectacleWeight
            ports.recurrence = clamp(Double((seenSectionLetters[section.letter] ?? 1) - 1) * 0.4, 0, 1)
        } else {
            ports.recurrence = clamp(Double(features.rms) * 0.4, 0, 0.5)
        }
        ports.release = releaseEnvelope.update(releaseTarget, dt: dt)

        let tempo = input.analysis?.tempo ?? 0
        let beatPhase = tempo > 0
            ? (input.trackTime * tempo / 60.0).truncatingRemainder(dividingBy: 1.0)
            : 0
        let beatCount = tempo > 0 ? Int(input.trackTime * tempo / 60.0) : 0

        var snapshot = RenderSnapshot(cue: cue, dna: input.dna)
        snapshot.programTime = input.programTime
        snapshot.trackTime = input.trackTime
        snapshot.sceneTime = max(0, input.programTime - cue.start)
        snapshot.deltaTime = dt
        snapshot.frameIndex = frameIndex
        snapshot.features = features
        snapshot.ports = ports
        snapshot.tempo = tempo
        snapshot.beatPhase = beatPhase
        snapshot.barPhase = tempo > 0
            ? (input.trackTime * tempo / 60.0 / 4.0).truncatingRemainder(dividingBy: 1.0)
            : 0
        snapshot.beatCount = beatCount
        snapshot.section = section
        snapshot.sectionProgress = section.map {
            clamp((input.trackTime - $0.start) / max(0.1, $0.duration), 0, 1)
        } ?? 0
        snapshot.confidence = input.analysis?.overallConfidence ?? 0
        snapshot.chapterLetter = input.score.chapter(at: input.programTime)?.letter ?? "A"
        return snapshot
    }
}
