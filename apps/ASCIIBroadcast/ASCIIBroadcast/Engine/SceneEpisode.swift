//
//  SceneEpisode.swift
//  ASCII Broadcast
//
//  Phase 1 §7. A scene is an entity or environment undergoing a legible
//  change: establishment, action, consequence, exit. Everything a scene needs
//  arrives as one immutable snapshot — scenes never read mutable audio state.
//

import Foundation

// MARK: - Smoothed music ports

/// Typed, smoothed signals with separate rise and fall behaviour. Scenes ask
/// for "pressure" or "articulation", not for FFT bin 37.
struct MusicPorts {
    var pressure: Double = 0        // low-band force, slow release
    var articulation: Double = 0    // transient detail, fast both ways
    var body: Double = 0            // midrange mass
    var air: Double = 0             // high band
    var brightness: Double = 0      // spectral centroid
    var density: Double = 0         // rhythmic activity
    var recurrence: Double = 0      // how familiar this passage is
    var release: Double = 0         // arrival / drop impulse, decays
    var impact: Double = 0          // single-frame transient strength
}

/// Attack/release envelope follower. Phase 1 §13: rising and falling behaviour
/// are separate so a kick can snap and then settle.
struct Envelope {
    var attack: Double
    var release: Double
    private(set) var value: Double = 0

    init(attack: Double, release: Double) {
        self.attack = attack
        self.release = release
    }

    mutating func update(_ target: Double, dt: Double) -> Double {
        let tau = target > value ? attack : release
        let coefficient = tau <= 0 ? 1 : 1 - exp(-dt / tau)
        value += (target - value) * clamp(coefficient, 0, 1)
        return value
    }

    mutating func reset(_ to: Double = 0) { value = to }
}

// MARK: - Snapshot

struct RenderSnapshot {
    var programTime: Double = 0
    var trackTime: Double = 0
    var sceneTime: Double = 0
    var deltaTime: Double = 1.0 / 30.0
    var frameIndex: Int = 0

    var features: FeatureFrame = .silent
    var ports: MusicPorts = MusicPorts()

    var tempo: Double = 0
    var beatPhase: Double = 0        // 0...1 within the beat
    var barPhase: Double = 0         // 0...1 within the bar
    var beatCount: Int = 0

    var section: MusicSection?
    var sectionProgress: Double = 0
    var confidence: Double = 0       // 0 = free-running performance

    var cue: ScoreSceneCue
    var dna: VisualDNA
    var chapterLetter: String = "A"

    /// 0...1 while a bridge between two scenes is in progress.
    var transitionProgress: Double?
    var transitionKind: TransitionKind?

    var reduceMotion: Bool { dna.reduceMotion }
    var motion: Double { dna.effectiveMotion }
    var detailTarget: Double { dna.detail.fillTarget }

    /// Free-running mode: the engine performs on its own clock when analysis
    /// is unavailable, and says so rather than inventing musical certainty.
    var isFreeRunning: Bool { confidence < 0.2 }
}

// MARK: - Carriers

/// Phase 1 §7: a small vocabulary of portable carriers moves identity between
/// families. Arbitrary geometry morphing between all pairs is not credible.
struct MotifCarrierState {
    var carrier: MotifCarrier
    var name: String
    var signature: String
    /// Normalised position in the frame, 0...1.
    var x: Double
    var y: Double
    var scale: Double = 1
    var role: PaletteRole = .accent
    var history: Int = 0
}

// MARK: - Scene protocol

protocol SceneEpisode: AnyObject {
    var family: SceneFamily { get }
    var episodeTitle: String { get }

    /// Called once when the episode becomes `prepared`. Must be cheap enough to
    /// run a frame ahead of going on air.
    func prepare(cue: ScoreSceneCue, dna: VisualDNA, columns: Int, rows: Int)

    /// Produce one frame of character state.
    func render(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary)

    /// What this episode can hand to the next one.
    func exitCarrier() -> MotifCarrierState?

    /// What this episode received from the previous one.
    func accept(carrier: MotifCarrierState)

    /// A simplified tableau used when quality steps down or a frame must be
    /// held. Never allowed to lose the focal action.
    func renderFallback(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary)
}

extension SceneEpisode {
    func renderFallback(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        render(into: grid, snapshot: snapshot, vocabulary: vocabulary)
    }
}

// MARK: - Shared scene helpers

/// One-point perspective projection on a character grid with 2:1 cells.
struct GridCamera {
    var columns: Int
    var rows: Int
    var vanishingX: Double      // 0...1
    var vanishingY: Double      // 0...1
    var focal: Double = 0.62

    /// World (x, y, z) -> cell coordinates. `z` is depth in metres-ish, > 0.
    func project(_ x: Double, _ y: Double, _ z: Double) -> (Int, Int, Double) {
        let depth = max(0.12, z)
        let scale = focal / depth
        let sx = vanishingX * Double(columns) + x * scale * Double(columns) * 0.5
        // Cells are twice as tall as wide, so vertical world units are halved.
        let sy = vanishingY * Double(rows) + y * scale * Double(rows) * 0.5
        return (Int(sx.rounded()), Int(sy.rounded()), scale)
    }

    func projectFloat(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
        let depth = max(0.12, z)
        let scale = focal / depth
        let sx = vanishingX * Double(columns) + x * scale * Double(columns) * 0.5
        let sy = vanishingY * Double(rows) + y * scale * Double(rows) * 0.5
        return (sx, sy, scale)
    }
}
